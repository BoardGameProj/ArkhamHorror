module Arkham.Enemy.Cards.HarlanEarnstoneCrazedByTheCurse (harlanEarnstoneCrazedByTheCurse) where

import Arkham.Ability
import Arkham.Enemy.Cards qualified as Cards
import Arkham.Enemy.Import.Lifted
import Arkham.Matcher

newtype HarlanEarnstoneCrazedByTheCurse = HarlanEarnstoneCrazedByTheCurse EnemyAttrs
  deriving anyclass (IsEnemy, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

harlanEarnstoneCrazedByTheCurse :: EnemyCard HarlanEarnstoneCrazedByTheCurse
harlanEarnstoneCrazedByTheCurse =
  enemy HarlanEarnstoneCrazedByTheCurse Cards.harlanEarnstoneCrazedByTheCurse (4, Static 2, 3) (1, 1)

instance HasAbilities HarlanEarnstoneCrazedByTheCurse where
  getAbilities (HarlanEarnstoneCrazedByTheCurse a) =
    extend1 a
      $ mkAbility a 1
      $ forced
      $ SkillTestResult #after You (WhileEvadingAnEnemy $ be a) (SuccessResult $ atLeast 3)

instance RunMessage HarlanEarnstoneCrazedByTheCurse where
  runMessage msg e@(HarlanEarnstoneCrazedByTheCurse attrs) = runQueueT $ case msg of
    UseThisAbility _ (isSource attrs -> True) 1 -> do
      addToVictory attrs
      pure e
    _ -> HarlanEarnstoneCrazedByTheCurse <$> liftRunMessage msg attrs
