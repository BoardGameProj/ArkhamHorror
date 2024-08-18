module Arkham.Act.Cards.BeginnersLuck (BeginnersLuck (..), beginnersLuck) where

import Arkham.Ability
import Arkham.Act.Cards qualified as Cards
import Arkham.Act.Runner
import Arkham.Card
import Arkham.ChaosToken
import Arkham.Classes
import Arkham.Deck qualified as Deck
import Arkham.Helpers.ChaosBag
import Arkham.Location.Cards qualified as Locations
import Arkham.Matcher
import Arkham.Prelude
import Arkham.ScenarioLogKey
import Arkham.Trait
import Arkham.Window qualified as Window

newtype BeginnersLuck = BeginnersLuck ActAttrs
  deriving anyclass (IsAct, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

-- Advancement is forced
beginnersLuck :: ActCard BeginnersLuck
beginnersLuck = act (1, A) BeginnersLuck Cards.beginnersLuck Nothing

instance HasAbilities BeginnersLuck where
  getAbilities (BeginnersLuck x) =
    extend x
      $ if onSide A x
        then
          [ groupLimit PerRound $ mkAbility x 1 $ freeReaction (RevealChaosToken #when Anyone AnyChaosToken)
          , mkAbility x 2
              $ Objective
              $ ForcedAbilityWithCost AnyWindow (GroupClueCost (PerPlayer 4) Anywhere)
          ]
        else []

instance RunMessage BeginnersLuck where
  runMessage msg a@(BeginnersLuck attrs) = case msg of
    UseCardAbility iid source 1 (Window.revealedChaosTokens -> [token]) _ | isSource attrs source -> do
      player <- getPlayer iid
      chaosTokensInBag <- getOnlyChaosTokensInBag
      pushAll
        [ FocusChaosTokens chaosTokensInBag
        , chooseOne
            player
            [ TargetLabel
              (ChaosTokenFaceTarget $ chaosTokenFace token')
              [ CreateChaosTokenEffect
                  ( EffectModifiers
                      $ toModifiers attrs [ChaosTokenFaceModifier [chaosTokenFace token']]
                  )
                  source
                  token
              , UnfocusChaosTokens
              , FocusChaosTokens [token']
              ]
            | token' <- chaosTokensInBag
            ]
        , Remember Cheated
        ]
      pure a
    UseCardAbility _ source 2 _ _ | isSource attrs source -> do
      push $ AdvanceAct (toId a) source AdvancedWithClues
      pure a
    AdvanceAct aid _ _ | aid == toId a && onSide B attrs -> do
      placeDarkenedHall <- placeSetAsideLocation_ Locations.darkenedHall
      lead <- getLead
      pushAll
        [ placeDarkenedHall
        , DiscardUntilFirst lead (toSource attrs) Deck.EncounterDeck
            $ basic (#enemy <> CardWithTrait Criminal)
        , AdvanceActDeck (actDeckId attrs) (toSource attrs)
        ]
      pure a
    RequestedEncounterCard source _ (Just ec) | isSource attrs source -> do
      darkenedHallId <- selectJust $ LocationWithTitle "Darkened Hall"
      push $ SpawnEnemyAt (EncounterCard ec) darkenedHallId
      pure a
    _ -> BeginnersLuck <$> runMessage msg attrs
