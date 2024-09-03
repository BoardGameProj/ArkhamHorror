module Arkham.Enemy.Cards.TheExperiment (
  TheExperiment (..),
  theExperiment,
) where

import Arkham.Prelude

import Arkham.Ability
import Arkham.Act.Cards qualified as Acts
import Arkham.Act.Sequence
import Arkham.Classes
import Arkham.Enemy.Cards qualified as Cards
import Arkham.Enemy.Runner
import Arkham.Matcher

newtype TheExperiment = TheExperiment EnemyAttrs
  deriving anyclass IsEnemy
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

theExperiment :: EnemyCard TheExperiment
theExperiment = enemy TheExperiment Cards.theExperiment (4, Static 7, 2) (2, 2)

instance HasAbilities TheExperiment where
  getAbilities (TheExperiment x) =
    withBaseAbilities x
      $ [ mkAbility x 1 $ ForcedAbility $ PhaseBegins #when #enemy
        , mkAbility x 2 $ Objective $ forced $ EnemyDefeated #when You ByAny (be x)
        ]

instance HasModifiersFor TheExperiment where
  getModifiersFor target (TheExperiment attrs) | isTarget attrs target = do
    modifier <- getPlayerCountValue (PerPlayer 3)
    pure $ toModifiers attrs [HealthModifier modifier]
  getModifiersFor _ _ = pure []

instance RunMessage TheExperiment where
  runMessage msg e@(TheExperiment attrs) = case msg of
    UseThisAbility _ (isSource attrs -> True) 1 -> do
      push $ Ready $ toTarget attrs
      pure e
    UseThisAbility _ (isSource attrs -> True) 2 -> do
      push $ AdvanceToAct 1 Acts.campusSafety B (toSource attrs)
      pure e
    _ -> TheExperiment <$> runMessage msg attrs
