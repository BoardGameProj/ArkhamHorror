module Arkham.Treachery.Cards.AlteredBeast (AlteredBeast (..), alteredBeast) where

import Arkham.Ability
import Arkham.Classes
import Arkham.Matcher
import Arkham.Prelude
import Arkham.Trait
import Arkham.Treachery.Cards qualified as Cards
import Arkham.Treachery.Runner

newtype AlteredBeast = AlteredBeast TreacheryAttrs
  deriving anyclass (IsTreachery, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

alteredBeast :: TreacheryCard AlteredBeast
alteredBeast = treachery AlteredBeast Cards.alteredBeast

instance HasAbilities AlteredBeast where
  getAbilities (AlteredBeast x) = case treacheryAttachedTarget x of
    Just (EnemyTarget eid) ->
      [ mkAbility x 1
          $ forced
          $ oneOf
            [EnemyEnters #when YourLocation $ EnemyWithId eid, Enters #when You (locationWithEnemy eid)]
      ]
    _ -> []

instance RunMessage AlteredBeast where
  runMessage msg t@(AlteredBeast attrs@TreacheryAttrs {..}) = case msg of
    Revelation iid (isSource attrs -> True) -> do
      abominations <- selectTargets $ EnemyWithTrait Abomination
      player <- getPlayer iid
      push $ case abominations of
        [] -> gainSurge attrs
        xs ->
          chooseOrRunOne player
            $ [ TargetLabel x [AttachTreachery treacheryId x, HealAllDamage x (toSource attrs)]
              | x <- xs
              ]
      pure t
    UseThisAbility iid (isSource attrs -> True) 1 -> do
      push $ assignHorror iid attrs 1
      pure t
    _ -> AlteredBeast <$> runMessage msg attrs
