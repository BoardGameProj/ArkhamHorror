module Arkham.Event.Cards.OccultInvocation (occultInvocation, OccultInvocation (..)) where

import Arkham.Aspect
import Arkham.Classes
import Arkham.Cost
import Arkham.Event.Cards qualified as Cards
import Arkham.Event.Runner
import Arkham.Fight
import Arkham.Helpers.Modifiers
import Arkham.Prelude

newtype OccultInvocation = OccultInvocation EventAttrs
  deriving anyclass (IsEvent, HasModifiersFor, HasAbilities)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

occultInvocation :: EventCard OccultInvocation
occultInvocation = event OccultInvocation Cards.occultInvocation

countCards :: Payment -> Int
countCards = \case
  DiscardCardPayment xs -> length xs
  Payments ps -> sum $ map countCards ps
  _ -> 0

instance RunMessage OccultInvocation where
  runMessage msg e@(OccultInvocation attrs) = case msg of
    PlayThisEvent iid eid | attrs `is` eid -> do
      let n = countCards attrs.payment
      chooseFight <-
        leftOr <$> aspect iid attrs (#willpower `InsteadOf` #combat) (mkChooseFight iid attrs)
      pushAll
        $ skillTestModifiers attrs iid [DamageDealt n, SkillModifier #intellect n]
        : chooseFight
      pure e
    _ -> OccultInvocation <$> runMessage msg attrs
