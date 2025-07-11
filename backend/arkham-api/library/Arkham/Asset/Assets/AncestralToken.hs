module Arkham.Asset.Assets.AncestralToken (ancestralToken) where

import Arkham.Ability
import Arkham.Asset.Cards qualified as Cards
import Arkham.Asset.Import.Lifted hiding (EnemyDefeated)
import Arkham.Enemy.Types (Field (EnemyHealthActual))
import Arkham.Helpers.Calculation
import Arkham.Helpers.ChaosBag
import Arkham.Helpers.Window
import Arkham.Matcher
import Arkham.Projection

newtype AncestralToken = AncestralToken AssetAttrs
  deriving anyclass (IsAsset, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

ancestralToken :: AssetCard AncestralToken
ancestralToken = assetWith AncestralToken Cards.ancestralToken (sanityL ?~ 2)

instance HasAbilities AncestralToken where
  getAbilities (AncestralToken a) =
    [restricted a 1 ControlsThis $ triggered (EnemyDefeated #after You ByAny AnyEnemy) (exhaust a)]

instance RunMessage AncestralToken where
  runMessage msg a@(AncestralToken attrs) = runQueueT $ case msg of
    UseCardAbility _iid (isSource attrs -> True) 1 (defeatedEnemy -> eid) _ -> do
      field EnemyHealthActual eid >>= traverse_ \healthValue -> do
        health <- calculate healthValue
        n <- getRemainingBlessTokens
        when (health > 0 && n > 0) do
          replicateM_ (min 5 (min n health)) $ addChaosToken #bless

      pure a
    _ -> AncestralToken <$> liftRunMessage msg attrs
