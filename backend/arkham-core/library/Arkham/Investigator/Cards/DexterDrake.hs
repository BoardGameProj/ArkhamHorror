module Arkham.Investigator.Cards.DexterDrake (
  dexterDrake,
  dexterDrakeEffect,
  DexterDrake (..),
)
where

import Arkham.Prelude

import Arkham.Ability
import Arkham.Asset.Cards qualified as Assets
import Arkham.Card
import Arkham.Effect.Runner ()
import Arkham.Effect.Types
import {-# SOURCE #-} Arkham.GameEnv
import Arkham.Helpers.Modifiers
import Arkham.Investigator.Cards qualified as Cards
import Arkham.Investigator.Runner
import Arkham.Matcher hiding (Discarded, DuringTurn)
import Arkham.Window (defaultWindows)

newtype DexterDrake = DexterDrake InvestigatorAttrs
  deriving anyclass (IsInvestigator, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

dexterDrake :: InvestigatorCard DexterDrake
dexterDrake =
  investigator DexterDrake Cards.dexterDrake
    $ Stats {health = 6, sanity = 8, willpower = 5, intellect = 2, combat = 3, agility = 2}

instance HasAbilities DexterDrake where
  getAbilities (DexterDrake a) =
    [ restrictedAbility
        a
        1
        ( Self
            <> DuringTurn You
            <> AnyCriterion
              [ PlayableCardExistsWithCostReduction
                  1
                  (HandCardWithDifferentTitleFromAtLeastOneAsset You AnyAsset AnyCard)
              , ExtendedCardExists (InHandOf You <> BasicCardMatch (cardIs Assets.occultScraps))
              ]
        )
        $ FastAbility
        $ DiscardAssetCost
        $ AssetWithDifferentTitleFromAtLeastOneCardInHand
          You
          (PlayableCardWithCostReduction NoAction 1 #asset)
          AnyAsset
    ]

instance HasChaosTokenValue DexterDrake where
  getChaosTokenValue iid ElderSign (DexterDrake attrs) | iid == toId attrs = do
    pure $ ChaosTokenValue ElderSign $ PositiveModifier 2
  getChaosTokenValue _ token _ = pure $ ChaosTokenValue token mempty

toCardPaid :: Payment -> Card
toCardPaid (DiscardPayment [(_, c)]) = c
toCardPaid _ = error "Invalid payment"

instance RunMessage DexterDrake where
  runMessage msg i@(DexterDrake attrs) = case msg of
    UseCardAbility iid (isSource attrs -> True) 1 _ (toCardPaid -> card) -> do
      cards <-
        select
          $ ExtendedCardWithOneOf
            [ PlayableCardWithCostReduction
                NoAction
                1
                ( InHandOf (InvestigatorWithId $ toId attrs)
                    <> BasicCardMatch (#asset <> NotCard (CardWithTitle $ toTitle card))
                )
            , InHandOf (InvestigatorWithId iid) <> BasicCardMatch (cardIs Assets.occultScraps)
            ]
      player <- getPlayer iid
      pushAll
        [ chooseOrRunOne player
            $ [ targetLabel (toCardId c)
                $ [ createCardEffect Cards.dexterDrake Nothing attrs (toCardId c)
                  , PayCardCost iid c $ defaultWindows iid
                  ]
              | c <- cards
              ]
        ]
      pure i
    _ -> DexterDrake <$> runMessage msg attrs

newtype DexterDrakeEffect = DexterDrakeEffect EffectAttrs
  deriving anyclass (HasAbilities, IsEffect)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

dexterDrakeEffect :: EffectArgs -> DexterDrakeEffect
dexterDrakeEffect = cardEffect DexterDrakeEffect Cards.dexterDrake

instance HasModifiersFor DexterDrakeEffect where
  getModifiersFor target@(CardIdTarget cid) (DexterDrakeEffect attrs) | effectTarget attrs == target = do
    card <- getCard cid
    pure
      $ toModifiers attrs
      $ [ReduceCostOf (CardWithId cid) 1]
      <> [CanPlayWithOverride (CriteriaOverride NoRestriction) | card `cardMatch` cardIs Assets.occultScraps]
  getModifiersFor _ _ = pure []

instance RunMessage DexterDrakeEffect where
  runMessage msg e@(DexterDrakeEffect attrs) = case msg of
    ResolvedCard _ card | CardIdTarget (toCardId card) == effectTarget attrs -> do
      push $ DisableEffect (toId attrs)
      pure e
    _ -> DexterDrakeEffect <$> runMessage msg attrs
