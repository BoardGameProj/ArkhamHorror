module Arkham.Asset.Cards.Switchblade (Switchblade (..), switchblade) where

import Arkham.Ability
import Arkham.Asset.Cards qualified as Cards
import Arkham.Asset.Runner
import Arkham.Fight
import Arkham.Prelude

newtype Switchblade = Switchblade AssetAttrs
  deriving anyclass (IsAsset, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

switchblade :: AssetCard Switchblade
switchblade = asset Switchblade Cards.switchblade

instance HasAbilities Switchblade where
  getAbilities (Switchblade a) = [restrictedAbility a 1 ControlsThis fightAction_]

instance RunMessage Switchblade where
  runMessage msg a@(Switchblade attrs) = case msg of
    UseThisAbility iid (isSource attrs -> True) 1 -> do
      pushM $ mkChooseFight iid (attrs.ability 1)
      pure a
    PassedThisSkillTestBy iid (isAbilitySource attrs 1 -> True) n -> do
      pushWhen (n >= 2) $ skillTestModifier attrs iid (DamageDealt 1)
      pure a
    _ -> Switchblade <$> runMessage msg attrs
