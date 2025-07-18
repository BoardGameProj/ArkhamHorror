{-# OPTIONS_GHC -Wno-orphans #-}

module Arkham.Helpers.Investigator where

import Arkham.Action
import Arkham.Asset.Types qualified as Field
import Arkham.CampaignLog
import Arkham.Capability
import Arkham.Card
import Arkham.Card.Settings
import Arkham.Classes.Entity
import Arkham.Classes.HasGame
import Arkham.Classes.HasQueue
import Arkham.Classes.Query
import Arkham.Criteria qualified as Criteria
import Arkham.Damage
import Arkham.Discover (IsInvestigate (..))
import {-# SOURCE #-} Arkham.GameEnv
import Arkham.GameValue
import Arkham.Helpers
import {-# SOURCE #-} Arkham.Helpers.Calculation (calculate)
import Arkham.Helpers.ChaosBag
import {-# SOURCE #-} Arkham.Helpers.Criteria
import Arkham.Helpers.Modifiers
import Arkham.Helpers.Slot
import Arkham.Id
import Arkham.Investigator.Types
import Arkham.Location.Types (Field (..))
import Arkham.Matcher hiding (InvestigatorDefeated, InvestigatorResigned, matchTarget)
import Arkham.Matcher qualified as Matcher
import Arkham.Message (
  Message (CheckWindows, Do, HealDamageDirectly, HealHorrorDirectly, InvestigatorMulligan),
 )
import Arkham.Name
import Arkham.Placement
import Arkham.Prelude
import Arkham.Projection
import Arkham.SkillType
import Arkham.Source
import Arkham.Stats
import Arkham.Target
import Arkham.Window (Window (..), WindowType (Healed))
import Data.Foldable (foldrM)
import Data.Function (on)
import Data.List (nubBy)
import Data.Map.Strict qualified as Map
import Data.Monoid

getSkillValue :: HasGame m => SkillType -> InvestigatorId -> m Int
getSkillValue st iid = do
  mods <- getModifiers iid
  let
    fld =
      case st of
        SkillWillpower -> InvestigatorBaseWillpower
        SkillIntellect -> InvestigatorBaseIntellect
        SkillCombat -> InvestigatorBaseCombat
        SkillAgility -> InvestigatorBaseAgility
  base <- field fld iid
  let canBeIncreased = SkillCannotBeIncreased st `notElem` mods
  x <-
    if canBeIncreased
      then
        let flat = sum [v | SkillModifier st' v <- mods, st' == st]
         in (+ flat) . sum <$> sequence [calculate calc | CalculatedSkillModifier st' calc <- mods, st' == st]
      else pure 0
  pure $ fromMaybe (x + base) $ minimumMay [n | SetSkillValue st' n <- mods, st' == st]

skillValueFor
  :: forall m
   . (HasCallStack, HasGame m)
  => SkillType
  -> Maybe Action
  -> InvestigatorId
  -> m Int
skillValueFor skill maction iid = go 2 skill =<< getModifiers iid
 where
  go :: Int -> SkillType -> [ModifierType] -> m Int
  go 0 _ _ = error "possible skillValueFor infinite loop"
  go depth s modifiers = do
    base <- baseSkillValueFor s maction iid
    base' <- foldrM applyBaseModifier base modifiers
    foldrM applyModifier base' modifiers
   where
    canBeIncreased = SkillCannotBeIncreased skill `notElem` modifiers
    matchingSkills = s : mapMaybe maybeAdditionalSkill modifiers -- must be the skill we are looking at
    maybeAdditionalSkill = \case
      SkillModifiersAffectOtherSkill s' t | t == skill -> Just s'
      _ -> Nothing
    applyBaseModifier (SetSkillValue s' n) m | s == s' && (n <= m || canBeIncreased) = pure n
    applyBaseModifier DoubleBaseSkillValue n | canBeIncreased = pure (n * 2)
    applyBaseModifier _ n = pure n
    applyModifier (AddSkillValue sv) n | canBeIncreased = do
      m <- getSkillValue sv iid
      pure $ max 0 (n + m)
    applyModifier (AddSkillValueOf sv iid') n | canBeIncreased = do
      m <- getSkillValue sv iid'
      pure $ max 0 (n + m)
    applyModifier (AddSkillToOtherSkill svAdd svType) n | canBeIncreased && svType `elem` matchingSkills = do
      m <- go (depth - 1) svAdd modifiers
      pure $ max 0 (n + m)
    applyModifier (SkillModifier skillType m) n
      | canBeIncreased || m < 0 =
          pure $ if skillType `elem` matchingSkills then max 0 (n + m) else n
    applyModifier (CalculatedSkillModifier skillType calc) n = do
      m <- calculate calc
      pure $ if (canBeIncreased || m < 0) && skillType `elem` matchingSkills then max 0 (n + m) else n
    applyModifier (ActionSkillModifier action skillType m) n | canBeIncreased || m < 0 = do
      pure
        $ if skillType `elem` matchingSkills && Just action == maction
          then max 0 (n + m)
          else n
    applyModifier _ n = pure n

baseSkillValueFor
  :: (HasCallStack, HasGame m)
  => SkillType
  -> Maybe Action
  -> InvestigatorId
  -> m Int
baseSkillValueFor skill _maction iid = do
  modifiers <- getModifiers iid
  let
    fld =
      case skill of
        SkillWillpower -> InvestigatorBaseWillpower
        SkillIntellect -> InvestigatorBaseIntellect
        SkillCombat -> InvestigatorBaseCombat
        SkillAgility -> InvestigatorBaseAgility
  baseValue <- field fld iid
  inner <- foldrM applyModifier baseValue modifiers
  pure $ foldr applyAfterModifier inner modifiers
 where
  applyModifier (BaseSkillOf skillType m) _ | skillType == skill = pure m
  applyModifier (BaseSkillOfCalculated skillType calc) _ | skillType == skill = calculate calc
  applyModifier (BaseSkill m) _ = pure m
  applyModifier _ n = pure n
  applyAfterModifier (SetSkillValue skillType m) _ | skillType == skill = m
  applyAfterModifier _ n = n

data DamageFor = DamageForEnemy | DamageForInvestigator
  deriving stock Eq

damageValueFor :: HasGame m => Int -> InvestigatorId -> DamageFor -> m Int
damageValueFor baseValue iid damageFor = do
  modifiers <- getModifiers (InvestigatorTarget iid)
  let baseValue' = if NoStandardDamage `elem` modifiers then 0 else baseValue
  foldrM applyModifier baseValue' modifiers
 where
  applyModifier (DamageDealt m) n = pure $ max 0 (n + m)
  applyModifier (CriteriaModifier c (DamageDealt m)) n = do
    passes <- passesCriteria iid Nothing GameSource GameSource [] c
    pure $ max 0 (n + if passes then m else 0)
  applyModifier (DamageDealtToInvestigator m) n | damageFor == DamageForInvestigator = pure $ max 0 (n + m)
  applyModifier NoDamageDealt _ = pure 0
  applyModifier _ n = pure n

getHandSize :: HasGame m => InvestigatorAttrs -> m Int
getHandSize attrs = do
  modifiers <- getModifiers (InvestigatorTarget $ investigatorId attrs)
  let ignoreReduction = IgnoreHandSizeReduction `elem` modifiers
  pure $ foldr (applyModifier ignoreReduction) (foldr applyMaxModifier 8 modifiers) modifiers
 where
  applyModifier ignoreReduction (HandSize m) n
    | m > 0 || not ignoreReduction = max 0 (n + m)
  applyModifier _ _ n = n
  applyMaxModifier (MaxHandSize m) n = min m n
  applyMaxModifier _ n = n

getInHandCount :: HasGame m => InvestigatorAttrs -> m Int
getInHandCount attrs = do
  onlyFirstCopies <- hasModifier attrs OnlyFirstCopyCardCountsTowardMaximumHandSize
  let f = if onlyFirstCopies then nubBy ((==) `on` toName) else id
  cards <- fieldMap InvestigatorHand f (toId attrs)
  let
    applyModifier n = \case
      HandSizeCardCount m -> m
      _ -> n
    getCardHandSize c = do
      modifiers <- getModifiers c
      pure $ foldl' applyModifier 1 modifiers
  sum <$> traverse getCardHandSize cards

getAbilitiesForTurn :: HasGame m => InvestigatorAttrs -> m Int
getAbilitiesForTurn attrs = do
  modifiers <- getModifiers (toTarget attrs)
  pure $ foldr applyModifier 3 modifiers
 where
  applyModifier (FewerActions m) n = max 0 (n - m)
  applyModifier _ n = n

canDiscoverCluesAtYourLocation :: HasGame m => IsInvestigate -> InvestigatorId -> m Bool
canDiscoverCluesAtYourLocation isInvestigate iid = do
  getMaybeLocation iid >>= \case
    Nothing -> pure False
    Just lid -> getCanDiscoverClues isInvestigate iid lid

getCanDiscoverClues
  :: HasGame m => IsInvestigate -> InvestigatorId -> LocationId -> m Bool
getCanDiscoverClues isInvestigation iid lid = do
  modifiers <- getModifiers iid
  hasClues <- fieldSome LocationClues lid
  (&& hasClues) . not <$> anyM match modifiers
 where
  match CannotDiscoverClues {} = pure True
  match (CannotDiscoverCluesAt matcher) = elem lid <$> select matcher
  match (CannotDiscoverCluesExceptAsResultOfInvestigation matcher) | isInvestigation == NotInvestigate = elem lid <$> select matcher
  match _ = pure False

getCanSpendClues
  :: (HasGame m, AsId investigator, IdOf investigator ~ InvestigatorId) => investigator -> m Bool
getCanSpendClues (asId -> iid) = do
  modifiers <- getModifiers iid
  pure $ not (any match modifiers)
 where
  match CannotSpendClues {} = True
  match _ = False

providedSlot :: Sourceable source => InvestigatorAttrs -> source -> Bool
providedSlot attrs source = any (any (isSlotSource source)) $ toList attrs.slots

removeFromSlots :: AssetId -> Map SlotType [Slot] -> Map SlotType [Slot]
removeFromSlots aid = fmap (map (removeIfMatches aid))

data FitsSlots = FitsSlots | MissingSlots [SlotType]
  deriving stock Show

fitsAvailableSlots :: HasGame m => AssetId -> InvestigatorAttrs -> m FitsSlots
fitsAvailableSlots aid a = do
  assetCard <- field Field.AssetCard aid
  slotTypes <- field Field.AssetSlots aid
  canHoldMap :: Map SlotType [SlotType] <- do
    mods <- getModifiers a
    let
      canHold = \case
        SlotCanBe slotType canBeSlotType -> insertWith (<>) slotType [canBeSlotType]
        _ -> id
    pure $ foldr canHold mempty mods

  -- N.B. we map (const slotType) in order to determine coverage. In other words if
  -- a card like The Hierophant V (3) is in play we have Accessory and Arcane
  -- slots actings as both, but for the sake of this function we'd need to make
  -- sure, for instance, all Arcane slots are covered by a card, so we'd count
  -- every Accessory Slot as an Arcane Slot
  -- WARNING This only works if the slots are bidirectional and if we need it
  -- to work in other cases we'll need to alter this logic
  let currentSlots =
        concatMap (\(k, xs) -> replicate (count (elem aid . slotItems) xs) k)
          $ Map.toList (a ^. slotsL)

  availableSlots <-
    concatForM
      (nub slotTypes)
      (\slotType -> map (const slotType) <$> availableSlotTypesFor slotType canHoldMap assetCard a.slots)
  let missingSlotTypes = slotTypes \\ (availableSlots <> currentSlots)

  pure $ if null missingSlotTypes then FitsSlots else MissingSlots missingSlotTypes

availableSlotTypesFor
  :: (IsCard a, HasGame m)
  => SlotType
  -> Map SlotType [SlotType]
  -> a
  -> Map SlotType [Slot]
  -> m [SlotType]
availableSlotTypesFor slotType canHoldMap a initSlots = do
  let possibleSlotTypes = slotType : findWithDefault [] slotType canHoldMap
  concatForM possibleSlotTypes $ \sType -> do
    let slots = findWithDefault [] sType initSlots
    xs <- filterM (canPutIntoSlot a) slots
    pure $ replicate (length xs) sType

nonEmptySlotsFirst :: [Slot] -> [Slot]
nonEmptySlotsFirst = sortOn isEmptySlot

standardSlotsLast :: [Slot] -> [Slot]
standardSlotsLast = sortOn isStandardSlot

placeInAvailableSlot :: (HasGame m, IsCard a) => AssetId -> a -> [Slot] -> m [Slot]
placeInAvailableSlot aid card = go . nonEmptySlotsFirst . standardSlotsLast
 where
  go [] = pure []
  go (x : xs) = do
    fits <- canPutIntoSlot card x
    if fits
      then pure $ putIntoSlot aid x : xs
      else (x :) <$> go xs

discardableCards :: InvestigatorAttrs -> [Card]
discardableCards InvestigatorAttrs {..} =
  if all cardIsWeakness investigatorHand
    then investigatorHand
    else filter (not . cardIsWeakness) investigatorHand

getAttrStats :: InvestigatorAttrs -> Stats
getAttrStats InvestigatorAttrs {..} =
  Stats
    { health = investigatorHealth
    , sanity = investigatorSanity
    , willpower = investigatorWillpower
    , intellect = investigatorIntellect
    , combat = investigatorCombat
    , agility = investigatorAgility
    }

investigatorWith
  :: (InvestigatorAttrs -> a)
  -> CardDef
  -> Stats
  -> (InvestigatorAttrs -> InvestigatorAttrs)
  -> CardBuilder PlayerId a
investigatorWith f cardDef stats g = investigator (f . g) cardDef stats

startsWith
  :: (Entity a, EntityAttrs a ~ InvestigatorAttrs)
  => [CardDef]
  -> CardBuilder PlayerId a
  -> CardBuilder PlayerId a
startsWith cards = fmap (overAttrs (startsWithL <>~ cards))

startsWithInHand
  :: (Entity a, EntityAttrs a ~ InvestigatorAttrs)
  => [CardDef]
  -> CardBuilder PlayerId a
  -> CardBuilder PlayerId a
startsWithInHand cards = fmap (overAttrs (startsWithInHandL <>~ cards))

investigator
  :: (InvestigatorAttrs -> a) -> CardDef -> Stats -> CardBuilder PlayerId a
investigator f cardDef Stats {..} =
  let iid = InvestigatorId (cdCardCode cardDef)
   in CardBuilder
        { cbCardCode = cdCardCode cardDef
        , cbCardBuilder = \_ pid ->
            f
              $ InvestigatorAttrs
                { investigatorId = iid
                , investigatorPlayerId = pid
                , investigatorName = cdName cardDef
                , investigatorCardCode = cdCardCode cardDef
                , investigatorArt = CardCodeExact $ cdCardCode cardDef
                , investigatorClass =
                    fromJustNote "missing class symbol"
                      . headMay
                      . setToList
                      $ cdClassSymbols cardDef
                , investigatorHealth = health
                , investigatorSanity = sanity
                , investigatorWillpower = willpower
                , investigatorIntellect = intellect
                , investigatorCombat = combat
                , investigatorAgility = agility
                , investigatorTokens = mempty
                , investigatorPlacement = Unplaced
                , investigatorActionsTaken = mempty
                , investigatorActionsPerformed = mempty
                , investigatorRemainingActions = 3
                , investigatorEndedTurn = False
                , investigatorDeck = mempty
                , investigatorSideDeck = mempty
                , investigatorDecks = mempty
                , investigatorDiscard = mempty
                , investigatorHand = mempty
                , investigatorTraits = cdCardTraits cardDef
                , investigatorKilled = False
                , investigatorDrivenInsane = False
                , investigatorDefeated = False
                , investigatorResigned = False
                , investigatorEliminated = False
                , investigatorSlots = defaultSlots iid
                , investigatorXp = 0
                , investigatorPhysicalTrauma = 0
                , investigatorMentalTrauma = 0
                , investigatorStartsWith = []
                , investigatorStartsWithInHand = []
                , investigatorCardsUnderneath = []
                , investigatorSearch = Nothing
                , investigatorMovement = Nothing
                , investigatorBondedCards = mempty
                , investigatorMeta = Null
                , investigatorUnhealedHorrorThisRound = 0
                , investigatorSealedChaosTokens = []
                , investigatorUsedAbilities = mempty
                , investigatorUsedAdditionalActions = mempty
                , investigatorMulligansTaken = 0
                , investigatorHorrorHealed = 0
                , investigatorSupplies = []
                , investigatorKeys = mempty
                , investigatorSeals = mempty
                , investigatorAssignedHealthDamage = 0
                , investigatorAssignedHealthHeal = mempty
                , investigatorAssignedSanityDamage = 0
                , investigatorAssignedSanityHeal = mempty
                , investigatorDrawnCards = []
                , investigatorForm = RegularForm
                , investigatorDiscarding = Nothing
                , investigatorDiscover = Nothing
                , investigatorDrawing = Nothing
                , investigatorSkippedWindow = False
                , investigatorLog = mkCampaignLog
                , investigatorDeckBuildingAdjustments = mempty
                , investigatorBeganRoundAt = Nothing
                , investigatorTaboo = Nothing
                , investigatorMutated = Nothing
                , investigatorDeckUrl = Nothing
                , investigatorSettings = defaultCardSettings
                }
        }

defaultSlots :: InvestigatorId -> Map SlotType [Slot]
defaultSlots iid =
  mapFromList
    [ (AccessorySlot, [Slot (InvestigatorSource iid) []])
    , (BodySlot, [Slot (InvestigatorSource iid) []])
    , (AllySlot, [Slot (InvestigatorSource iid) []])
    ,
      ( HandSlot
      ,
        [ Slot (InvestigatorSource iid) []
        , Slot (InvestigatorSource iid) []
        ]
      )
    ,
      ( ArcaneSlot
      ,
        [ Slot (InvestigatorSource iid) []
        , Slot (InvestigatorSource iid) []
        ]
      )
    , (TarotSlot, [Slot (InvestigatorSource iid) []])
    ]

getSpendableClueCount
  :: (HasGame m, AsId investigator, IdOf investigator ~ InvestigatorId) => investigator -> m Int
getSpendableClueCount (asId -> iid) = do
  canSpendClues <- getCanSpendClues iid
  if canSpendClues then field InvestigatorClues iid else pure 0

getCanSpendNClues :: HasGame m => InvestigatorId -> Int -> m Bool
getCanSpendNClues iid n = iid <=~> InvestigatorCanSpendClues (Static n)

drawOpeningHand
  :: (HasCallStack, HasGame m) => InvestigatorAttrs -> Int -> m ([PlayerCard], [Card], [PlayerCard])
drawOpeningHand a n = do
  replaceWeaknesses <- not <$> hasModifier a CannotReplaceWeaknesses
  pure $ go replaceWeaknesses (max 0 n) (a ^. discardL, a ^. handL, coerce (a ^. deckL))
 where
  go _ 0 (d, h, cs) = (d, h, cs)
  go _ _ (_, _, []) =
    error $ "this should never happen, it means the deck was empty during drawing: " <> show a.id
  go replaceWeaknesses m (d, h, c : cs) =
    if isJust (cdCardSubType $ toCardDef c) && cdCanReplace (toCardDef c) && replaceWeaknesses
      then go replaceWeaknesses m (c : d, h, cs)
      else go replaceWeaknesses (m - 1) (d, PlayerCard c : h, cs)

canCommitToAnotherLocation
  :: HasGame m => InvestigatorId -> LocationId -> m Bool
canCommitToAnotherLocation iid otherLocation = do
  modifiers <- getModifiers iid
  if CannotCommitToOtherInvestigatorsSkillTests `elem` modifiers
    then pure False
    else anyM permit modifiers
 where
  permit (CanCommitToSkillTestPerformedByAnInvestigatorAt matcher) = elem otherLocation <$> select matcher
  permit _ = pure False

findCard :: HasCallStack => CardId -> InvestigatorAttrs -> Card
findCard cardId a =
  fromJustNote "not in hand or discard or deck"
    $ findMatch
    $ (a ^. handL)
    <> map PlayerCard (a ^. discardL)
    <> map PlayerCard (unDeck $ a ^. deckL)
 where
  findMatch = find ((== cardId) . toCardId)

getJustLocation
  :: (HasCallStack, HasGame m) => InvestigatorId -> m LocationId
getJustLocation = fieldJust InvestigatorLocation

getMaybeLocation
  :: (HasGame m, AsId investigator, IdOf investigator ~ InvestigatorId)
  => investigator
  -> m (Maybe LocationId)
getMaybeLocation = fmap join . fieldMay InvestigatorLocation . asId

enemiesColocatedWith :: InvestigatorId -> EnemyMatcher
enemiesColocatedWith = EnemyAt . LocationWithInvestigator . InvestigatorWithId

modifiedStatsOf
  :: HasGame m => Maybe Action -> InvestigatorId -> m Stats
modifiedStatsOf maction i = do
  remainingHealth <- field InvestigatorRemainingHealth i
  remainingSanity <- field InvestigatorRemainingSanity i
  willpower' <- skillValueFor SkillWillpower maction i
  intellect' <- skillValueFor SkillIntellect maction i
  combat' <- skillValueFor SkillCombat maction i
  agility' <- skillValueFor SkillAgility maction i
  pure
    Stats
      { willpower = willpower'
      , intellect = intellect'
      , combat = combat'
      , agility = agility'
      , health = remainingHealth
      , sanity = remainingSanity
      }

getAvailableSkillsFor
  :: HasGame m => SkillType -> InvestigatorId -> m (Set SkillType)
getAvailableSkillsFor skillType iid = do
  modifiers <- getModifiers (InvestigatorTarget iid)
  pure $ foldr applyModifier (singleton skillType) modifiers
 where
  applyModifier (UseSkillInPlaceOf toReplace toUse) skills
    | toReplace == skillType = insertSet toUse skills
  applyModifier _ skills = skills

isEliminated :: (HasCallStack, HasGame m) => InvestigatorId -> m Bool
isEliminated iid =
  orM $ sequence [field InvestigatorResigned, field InvestigatorDefeated] iid

getHandCount :: HasGame m => InvestigatorId -> m Int
getHandCount = fieldMap InvestigatorHand length

canTriggerParallelRex :: HasGame m => InvestigatorId -> m Bool
canTriggerParallelRex =
  ( <=~>
      ( InvestigatorIs "90078"
          <> InvestigatorWhenCriteria (Criteria.HasNRemainingCurseTokens (atLeast 2))
      )
  )

getCanPlaceCluesOnLocationCount :: HasGame m => InvestigatorId -> m Int
getCanPlaceCluesOnLocationCount iid = do
  canRex <- canTriggerParallelRex iid
  m <- if canRex then (`div` 2) <$> getRemainingCurseTokens else pure 0
  (+ m) <$> field InvestigatorClues iid

canHaveHorrorHealed :: (HasGame m, Sourceable a) => a -> InvestigatorId -> m Bool
canHaveHorrorHealed a = selectAny . HealableInvestigator (toSource a) HorrorType . InvestigatorWithId

canHaveDamageHealed :: (HasGame m, Sourceable a) => a -> InvestigatorId -> m Bool
canHaveDamageHealed a = selectAny . HealableInvestigator (toSource a) DamageType . InvestigatorWithId

-- canFight <- selectAny $ CanFightEnemy source <> EnemyWithBounty
-- canEngage <- selectAny $ CanEngageEnemy <> EnemyWithBounty
-- pure $ (canFight && maction == Just #fight) || (canEngage && maction == Just #engage)

eliminationWindow :: InvestigatorId -> WindowMatcher
eliminationWindow iid = OrWindowMatcher [GameEnds #when, InvestigatorEliminated #when (InvestigatorWithId iid)]

getCanShuffleDeck :: HasGame m => InvestigatorId -> m Bool
getCanShuffleDeck iid =
  andM
    [ withoutModifier iid CannotManipulateDeck
    , fieldMap InvestigatorDeck notNull iid
    ]

check :: (EntityId a ~ InvestigatorId, Entity a, HasGame m) => a -> InvestigatorMatcher -> m Bool
check (toId -> iid) capability = iid <=~> capability

checkAll
  :: (EntityId a ~ InvestigatorId, Entity a, HasGame m) => a -> [InvestigatorMatcher] -> m Bool
checkAll (toId -> iid) capabilities = iid <=~> fold capabilities

searchBonded :: (HasGame m, AsId iid, IdOf iid ~ InvestigatorId) => iid -> CardDef -> m [Card]
searchBonded (asId -> iid) def = fieldMap InvestigatorBondedCards (filter ((== def) . toCardDef)) iid

searchBondedJust :: (HasGame m, AsId iid, IdOf iid ~ InvestigatorId) => iid -> CardDef -> m Card
searchBondedJust (asId -> iid) def =
  fromJustNote "must be"
    . listToMaybe
    <$> fieldMap InvestigatorBondedCards (filter ((== def) . toCardDef)) iid

searchBondedFor
  :: (HasGame m, AsId iid, IdOf iid ~ InvestigatorId) => iid -> CardMatcher -> m [Card]
searchBondedFor (asId -> iid) matcher = fieldMap InvestigatorBondedCards (filter (`cardMatch` matcher)) iid

-- TODO: Decide if we want to use or keep these instances, these let you do
-- >       canModifyDeck <- can.manipulate.deck attrs

instance HasGame m => Capable (InvestigatorId -> m Bool) where
  can =
    let can' = can :: Capabilities InvestigatorMatcher
     in fmap (flip (<=~>)) can'

instance HasGame m => Capable (FromSource -> InvestigatorId -> m Bool) where
  can =
    let can' = can :: Capabilities (FromSource -> InvestigatorMatcher)
     in fmap (\m fSource iid -> iid <=~> m fSource) can'

instance HasGame m => Capable (InvestigatorAttrs -> m Bool) where
  can =
    let can' = can :: Capabilities InvestigatorMatcher
     in fmap (\c -> (<=~> c) . toId) can'

instance HasGame m => Capable (FromSource -> InvestigatorAttrs -> m Bool) where
  can =
    let can' = can :: Capabilities (FromSource -> InvestigatorMatcher)
     in fmap (\c fSource attrs -> toId attrs <=~> c fSource) can'

guardAffectsOthers :: HasGame m => InvestigatorId -> InvestigatorMatcher -> m InvestigatorMatcher
guardAffectsOthers iid matcher = do
  -- This is mainly for self centered
  selfCentered <- hasModifier iid CannotAffectOtherPlayersWithPlayerEffectsExceptDamage
  pure $ if selfCentered then matcher <> InvestigatorWithId iid else matcher

guardAffectsColocated :: HasGame m => InvestigatorId -> m InvestigatorMatcher
guardAffectsColocated iid = guardAffectsOthers iid (colocatedWith iid)

getInMulligan :: HasQueue Message m => m Bool
getInMulligan = fromQueue (any isMulligan)
 where
  isMulligan = \case
    InvestigatorMulligan {} -> True
    _ -> False

setMeta :: ToJSON a => a -> InvestigatorAttrs -> InvestigatorAttrs
setMeta meta attrs = attrs & metaL .~ toJSON meta

healAdditional
  :: (Sourceable source, HasQueue Message m) => source -> DamageType -> [Window] -> Int -> m ()
healAdditional (toSource -> source) dType ws' additional = do
  -- this is meant to heal additional so we'd directly heal one more
  -- (without triggering a window), and then overwrite the original window
  -- to heal for one more
  let
    updateHealed = \case
      Window timing (Healed dType' t s n) mBatchId
        | dType == dType' ->
            Window timing (Healed dType' t s (n + additional)) mBatchId
      other -> other
    getHealedTarget = \case
      (windowType -> Healed dType' t _ _) | dType == dType' -> Just t
      _ -> Nothing
    healedTarget = fromJustNote "wrong call" $ getFirst $ foldMap (First . getHealedTarget) ws'

  replaceMessageMatching
    \case
      CheckWindows ws -> ws == ws'
      Do (CheckWindows ws) -> ws == ws'
      _ -> False
    \case
      CheckWindows ws -> [CheckWindows $ map updateHealed ws]
      Do (CheckWindows ws) -> [Do (CheckWindows $ map updateHealed ws)]
      _ -> error "invalid window"
  case dType of
    HorrorType -> push $ HealHorrorDirectly healedTarget source 1
    DamageType -> push $ HealDamageDirectly healedTarget source 1

getAsIfInHandCards :: (HasCallStack, HasGame m) => InvestigatorId -> m [Card]
getAsIfInHandCards iid = do
  modifiers <- getModifiers (InvestigatorTarget iid)
  let
    modifiersPermitPlayOfDiscard discard c =
      any (modifierPermitsPlayOfDiscard discard c) modifiers
    modifierPermitsPlayOfDiscard discard (c, _) = \case
      CanPlayFromDiscard cardMatcher -> c `cardMatch` cardMatcher && c `elem` discard
      CanPlayTopmostOfDiscard (mType, traits) ->
        let cardMatcher = maybe AnyCard CardWithType mType <> foldMap CardWithTrait traits
            allMatches = filter (`cardMatch` cardMatcher) discard
         in case allMatches of
              (topmost : _) -> topmost == c
              _ -> False
      _ -> False
    modifiersPermitPlayOfDeck c = any (modifierPermitsPlayOfDeck c) modifiers
    modifierPermitsPlayOfDeck (c, depth) = \case
      CanPlayTopOfDeck cardMatcher | depth == 0 -> cardMatch c cardMatcher
      _ -> False
  cardsAddedViaModifiers <- flip mapMaybeM modifiers $ \case
    AsIfInHand c -> pure $ Just c
    AsIfInHandForPlay c -> Just <$> getCard c
    _ -> pure Nothing
  discard <- field InvestigatorDiscard iid
  deck <- fieldMap InvestigatorDeck unDeck iid
  pure
    $ map
      (PlayerCard . fst)
      (filter (modifiersPermitPlayOfDiscard discard) (zip discard [0 :: Int ..]))
    <> map
      (PlayerCard . fst)
      (filter modifiersPermitPlayOfDeck (zip deck [0 :: Int ..]))
    <> cardsAddedViaModifiers

matchWho
  :: HasGame m
  => InvestigatorId
  -> InvestigatorId
  -> Matcher.InvestigatorMatcher
  -> m Bool
matchWho iid who Matcher.You = pure $ iid == who
matchWho iid who Matcher.NotYou = pure $ iid /= who
matchWho _ _ Matcher.Anyone = pure True
matchWho iid who (Matcher.InvestigatorAt matcher) = do
  who <=~> Matcher.InvestigatorAt (Matcher.replaceYouMatcher iid matcher)
matchWho iid who matcher = do
  matcher' <- replaceMatchWhoLocations iid (Matcher.replaceYouMatcher iid matcher)
  who <=~> matcher'
 where
  replaceMatchWhoLocations iid' = \case
    Matcher.InvestigatorAt matcher' -> do
      pure $ Matcher.InvestigatorAt $ Matcher.replaceYouMatcher iid matcher'
    Matcher.HealableInvestigator source damageType inner -> do
      Matcher.HealableInvestigator source damageType
        <$> replaceMatchWhoLocations iid' inner
    other -> pure other

getCardAttachments :: (HasGame m, HasCardCode c) => InvestigatorId -> c -> m [CardCode]
getCardAttachments iid c = fromMaybe [] <$> getMaybeCardAttachments iid c

getMaybeCardAttachments :: (HasGame m, HasCardCode c) => InvestigatorId -> c -> m (Maybe [CardCode])
getMaybeCardAttachments iid c = do
  settings <- field InvestigatorSettings iid
  pure $ cardAttachments <$> lookup (toCardCode c) (perCardSettings settings)

getCanLoseActions
  :: (HasGame m, AsId investigator, IdOf investigator ~ InvestigatorId) => investigator -> m Bool
getCanLoseActions (asId -> iid) = do
  remaining <- field InvestigatorRemainingActions iid
  additional <- fieldLength InvestigatorAdditionalActions iid
  pure $ remaining + additional > 0
