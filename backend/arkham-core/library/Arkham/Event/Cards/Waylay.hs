module Arkham.Event.Cards.Waylay (
  waylay,
  Waylay (..),
) where

import Arkham.Prelude

import Arkham.Classes
import Arkham.Enemy.Types (Field (..))
import Arkham.Event.Cards qualified as Cards
import Arkham.Event.Runner
import Arkham.Helpers.Enemy
import Arkham.Matcher
import Arkham.SkillType

newtype Waylay = Waylay EventAttrs
  deriving anyclass (IsEvent, HasModifiersFor, HasAbilities)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

waylay :: EventCard Waylay
waylay = event Waylay Cards.waylay

instance RunMessage Waylay where
  runMessage msg e@(Waylay attrs) = case msg of
    InvestigatorPlayEvent iid eid _ _ _ | eid == toId attrs -> do
      enemies <-
        selectWithField EnemyEvade
          $ NonEliteEnemy
          <> EnemyAt (LocationWithInvestigator $ InvestigatorWithId iid)
          <> ExhaustedEnemy
      let
        enemiesWithEvade =
          flip mapMaybe enemies $ \(enemy, mEvade) -> (enemy,) <$> mEvade
      player <- getPlayer iid
      pushAll
        [ chooseOne
            player
            [ targetLabel
              enemy
              [ beginSkillTest
                  iid
                  (toSource attrs)
                  (EnemyTarget enemy)
                  SkillAgility
                  (EnemyMaybeFieldDifficulty enemy EnemyEvade)
              ]
            | (enemy, _) <- enemiesWithEvade
            ]
        ]
      pure e
    PassedSkillTest iid _ (isSource attrs -> True) (SkillTestInitiatorTarget (EnemyTarget eid)) _ _ ->
      do
        pushAllM $ defeatEnemy eid iid attrs
        pure e
    _ -> Waylay <$> runMessage msg attrs
