module Arkham.Event.Cards.BloodEclipse3 (bloodEclipse3, BloodEclipse3 (..)) where

import Arkham.Aspect
import Arkham.Classes
import Arkham.Cost
import Arkham.Event.Cards qualified as Cards
import Arkham.Event.Runner
import Arkham.Fight
import Arkham.Helpers.Modifiers
import Arkham.Prelude

newtype BloodEclipse3 = BloodEclipse3 EventAttrs
  deriving anyclass (IsEvent, HasModifiersFor, HasAbilities)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

bloodEclipse3 :: EventCard BloodEclipse3
bloodEclipse3 = event BloodEclipse3 Cards.bloodEclipse3

countDamage :: Payment -> Int
countDamage = \case
  InvestigatorDamagePayment n -> n
  Payments ps -> sum $ map countDamage ps
  _ -> 0

instance RunMessage BloodEclipse3 where
  runMessage msg e@(BloodEclipse3 attrs) = case msg of
    PlayThisEvent iid eid | attrs `is` eid -> do
      let n = countDamage attrs.payment
      chooseFight <-
        leftOr <$> aspect iid attrs (#willpower `InsteadOf` #combat) (mkChooseFight iid attrs)
      pushAll $ skillTestModifiers attrs iid [DamageDealt n, SkillModifier #willpower n] : chooseFight
      pure e
    _ -> BloodEclipse3 <$> runMessage msg attrs
