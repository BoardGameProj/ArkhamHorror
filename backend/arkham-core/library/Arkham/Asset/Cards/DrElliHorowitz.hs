module Arkham.Asset.Cards.DrElliHorowitz (
  drElliHorowitz,
  DrElliHorowitz (..),
) where

import Arkham.Prelude

import Arkham.Ability
import Arkham.Asset.Cards qualified as Cards
import Arkham.Asset.Runner
import Arkham.Card
import Arkham.ChaosBag.Base
import Arkham.Keyword (Sealing (..))
import Arkham.Keyword qualified as Keyword
import Arkham.Matcher
import Arkham.Placement
import Arkham.Projection
import Arkham.Scenario.Types (Field (..))
import Arkham.Timing qualified as Timing
import Arkham.Trait

newtype DrElliHorowitz = DrElliHorowitz AssetAttrs
  deriving anyclass (IsAsset)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

drElliHorowitz :: AssetCard DrElliHorowitz
drElliHorowitz = ally DrElliHorowitz Cards.drElliHorowitz (1, 2)

instance HasModifiersFor DrElliHorowitz where
  getModifiersFor (AssetTarget aid) (DrElliHorowitz a) | aid /= toId a = do
    controller <- field AssetController (toId a)
    case controller of
      Nothing -> pure []
      Just iid -> do
        placement <- field AssetPlacement aid
        pure case placement of
          AttachedToAsset aid' _ | aid' == toId a -> toModifiers a [AsIfUnderControlOf iid]
          _ -> []
  getModifiersFor _ _ = pure []

instance HasAbilities DrElliHorowitz where
  getAbilities (DrElliHorowitz a) =
    [ restrictedAbility a 1 (ControlsThis <> CanManipulateDeck)
        $ ReactionAbility
          (AssetEntersPlay Timing.When $ AssetWithId $ toId a)
          Free
    ]

instance RunMessage DrElliHorowitz where
  runMessage msg a@(DrElliHorowitz attrs) = case msg of
    UseCardAbility iid source 1 _ _ | isSource attrs source -> do
      push
        $ search iid source iid [fromTopOfDeck 9] AnyCard -- no filter because we need to handle game logic
        $ DeferSearchedToTarget (toTarget attrs)
      pure a
    SearchFound iid (isTarget attrs -> True) _ cards -> do
      validCards <-
        pure
          $ filter
            (`cardMatch` (CardWithType AssetType <> CardWithTrait Relic))
            cards
      tokens <- scenarioFieldMap ScenarioChaosBag chaosBagChaosTokens
      let
        validAfterSeal c = do
          let
            sealChaosTokenMatchers =
              flip mapMaybe (setToList $ cdKeywords $ toCardDef c) $ \case
                Keyword.Seal sealing -> case sealing of
                  Sealing matcher -> Just matcher
                  SealUpTo _ matcher -> Just matcher
                  SealUpToX _ -> Nothing
                _ -> Nothing
          allM
            (\matcher -> anyM (\t -> matchChaosToken iid t matcher) tokens)
            sealChaosTokenMatchers
      validCardsAfterSeal <- filterM validAfterSeal validCards
      player <- getPlayer iid
      if null validCardsAfterSeal
        then push $ chooseOne player [Label "No Cards Found" []]
        else do
          assetId <- getRandom
          additionalTargets <- getAdditionalSearchTargets iid
          push
            $ chooseN
              player
              (min (length validCardsAfterSeal) (1 + additionalTargets))
              [ targetLabel
                (toCardId c)
                [ CreateAssetAt assetId c
                    $ AttachedToAsset (toId attrs) (Just $ InPlayArea iid)
                ]
              | c <- validCardsAfterSeal
              ]
      pure a
    SearchNoneFound iid target | isTarget attrs target -> do
      player <- getPlayer iid
      push $ chooseOne player [Label "No Cards Found" []]
      pure a
    _ -> DrElliHorowitz <$> runMessage msg attrs
