module Arkham.Treachery.Cards.AccursedFate (
  accursedFate,
  AccursedFate (..),
) where

import Arkham.Prelude

import Arkham.CampaignLogKey
import Arkham.Card
import Arkham.Classes
import Arkham.Deck qualified as Deck
import Arkham.Helpers.Log
import Arkham.Treachery.Cards qualified as Cards
import Arkham.Treachery.Runner

newtype AccursedFate = AccursedFate TreacheryAttrs
  deriving anyclass (IsTreachery, HasModifiersFor, HasAbilities)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

accursedFate :: TreacheryCard AccursedFate
accursedFate = treachery AccursedFate Cards.accursedFate

instance RunMessage AccursedFate where
  runMessage msg t@(AccursedFate attrs) = case msg of
    Revelation iid (isSource attrs -> True) -> do
      theHourIsNight <- getHasRecord TheHourIsNigh
      if theHourIsNight
        then do
          theBellTolls <- genPlayerCard Cards.theBellTolls
          case toCard attrs of
            EncounterCard _ -> error "not an encounter card"
            VengeanceCard _ -> error "not a vengeance card"
            PlayerCard pc ->
              pushAll
                [ assignHorror iid attrs 2
                , RemoveCardFromDeckForCampaign iid pc
                , AddCardToDeckForCampaign iid theBellTolls
                , PutCardOnBottomOfDeck iid (Deck.InvestigatorDeck iid) (toCard theBellTolls)
                , RemoveTreachery (toId attrs)
                ]
        else pushAll [assignHorror iid attrs 2, Record TheHourIsNigh]

      pure t
    _ -> AccursedFate <$> runMessage msg attrs
