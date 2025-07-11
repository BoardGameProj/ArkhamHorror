module Arkham.Asset.Assets.Grounded3 (grounded3) where

import Arkham.Ability
import Arkham.Asset.Cards qualified as Cards
import Arkham.Asset.Import.Lifted
import Arkham.Helpers.Modifiers (ModifierType (..), controllerGets, modifySelf)
import Arkham.Helpers.SkillTest (withSkillTest)
import Arkham.Matcher
import Arkham.Trait (Trait (Spell))

newtype Grounded3 = Grounded3 AssetAttrs
  deriving anyclass IsAsset
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

grounded3 :: AssetCard Grounded3
grounded3 = assetWith Grounded3 Cards.grounded3 $ (healthL ?~ 2) . (sanityL ?~ 2)

instance HasAbilities Grounded3 where
  getAbilities (Grounded3 x) =
    [ wantsSkillTest (YourSkillTest $ SkillTestOnCardWithTrait Spell)
        $ controlled x 1 (DuringSkillTest $ SkillTestOnCardWithTrait Spell)
        $ FastAbility (ResourceCost 1)
    ]

instance HasModifiersFor Grounded3 where
  getModifiersFor (Grounded3 a) = do
    modifySelf a [NonDirectHorrorMustBeAssignToThisFirst, NonDirectDamageMustBeAssignToThisFirst]
    controllerGets a [AnySkillValue 1]

instance RunMessage Grounded3 where
  runMessage msg a@(Grounded3 attrs) = runQueueT $ case msg of
    UseThisAbility iid (isSource attrs -> True) 1 -> do
      withSkillTest \sid -> skillTestModifiers sid (attrs.ability 1) iid [AnySkillValue 1]
      pure a
    _ -> Grounded3 <$> liftRunMessage msg attrs
