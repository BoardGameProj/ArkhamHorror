module Arkham.Enemy.Cards.HenryDeveauAlejandrosKidnapper (henryDeveauAlejandrosKidnapper) where

import Arkham.Enemy.Cards qualified as Cards
import Arkham.Enemy.Import.Lifted

newtype HenryDeveauAlejandrosKidnapper = HenryDeveauAlejandrosKidnapper EnemyAttrs
  deriving anyclass (IsEnemy, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity, HasAbilities)

henryDeveauAlejandrosKidnapper :: EnemyCard HenryDeveauAlejandrosKidnapper
henryDeveauAlejandrosKidnapper =
  enemy HenryDeveauAlejandrosKidnapper Cards.henryDeveauAlejandrosKidnapper (4, Static 3, 2) (1, 1)

instance RunMessage HenryDeveauAlejandrosKidnapper where
  runMessage msg (HenryDeveauAlejandrosKidnapper attrs) =
    HenryDeveauAlejandrosKidnapper <$> runMessage msg attrs
