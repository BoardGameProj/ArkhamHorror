module Arkham.Treachery.Cards.Doomed (
  doomed,
  Doomed (..),
) where

import Arkham.Prelude

import Arkham.CampaignLogKey
import Arkham.Card
import Arkham.Classes
import Arkham.Deck qualified as Deck
import Arkham.Helpers.Log
import Arkham.Treachery.Cards qualified as Cards
import Arkham.Treachery.Runner

newtype Doomed = Doomed TreacheryAttrs
  deriving anyclass (IsTreachery, HasModifiersFor, HasAbilities)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

doomed :: TreacheryCard Doomed
doomed = treachery Doomed Cards.doomed

instance RunMessage Doomed where
  runMessage msg t@(Doomed attrs) = case msg of
    Revelation iid source | isSource attrs source -> do
      doomApproached <- getHasRecord DoomApproaches
      if doomApproached
        then do
          accursedFate <- genPlayerCard Cards.accursedFate
          case toCard attrs of
            VengeanceCard _ -> error "not a vengeance card"
            EncounterCard _ -> error "not an encounter card"
            PlayerCard pc ->
              pushAll
                [ InvestigatorAssignDamage iid source DamageAny 0 1
                , RemoveCardFromDeckForCampaign iid pc
                , AddCardToDeckForCampaign iid accursedFate
                , PutCardOnBottomOfDeck
                    iid
                    (Deck.InvestigatorDeck iid)
                    (toCard accursedFate)
                , RemoveTreachery (toId attrs)
                ]
        else do
          pushAll
            $ [ InvestigatorAssignDamage iid source DamageAny 0 1
              , Record DoomApproaches
              ]

      pure t
    _ -> Doomed <$> runMessage msg attrs
