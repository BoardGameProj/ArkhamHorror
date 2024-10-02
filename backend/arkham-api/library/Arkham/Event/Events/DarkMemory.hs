module Arkham.Event.Events.DarkMemory where

import Arkham.Prelude

import Arkham.Ability
import Arkham.Card
import Arkham.Classes
import Arkham.Event.Cards qualified as Cards
import Arkham.Event.Runner
import Arkham.Matcher

newtype DarkMemory = DarkMemory EventAttrs
  deriving anyclass (IsEvent, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

darkMemory :: EventCard DarkMemory
darkMemory = event DarkMemory Cards.darkMemory

instance HasAbilities DarkMemory where
  getAbilities (DarkMemory x) = [restrictedAbility x 1 InYourHand $ ForcedAbility $ TurnEnds #when You]

instance RunMessage DarkMemory where
  runMessage msg e@(DarkMemory attrs) = case msg of
    InHand iid' (UseThisAbility iid (isSource attrs -> True) 1) | iid' == iid -> do
      pushAll
        [ RevealCard $ toCardId attrs
        , assignHorror iid (CardIdSource $ toCardId attrs) 2
        ]
      pure e
    PlayThisEvent _ eid | attrs `is` eid -> do
      push placeDoomOnAgendaAndCheckAdvance
      pure e
    _ -> DarkMemory <$> runMessage msg attrs
