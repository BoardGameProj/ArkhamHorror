module Arkham.Asset.Assets.LeoDeLuca where

import Arkham.Asset.Cards qualified as Cards
import Arkham.Asset.Import.Lifted
import Arkham.Modifier

newtype LeoDeLuca = LeoDeLuca AssetAttrs
  deriving anyclass (IsAsset, HasAbilities)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

leoDeLuca :: AssetCard LeoDeLuca
leoDeLuca = ally LeoDeLuca Cards.leoDeLuca (2, 2)

instance HasModifiersFor LeoDeLuca where
  getModifiersFor (InvestigatorTarget iid) (LeoDeLuca a) = do
    modified a [AdditionalActions "Leo De Luca" (toSource a) 1 | controlledBy a iid]
  getModifiersFor _ _ = pure []

instance RunMessage LeoDeLuca where
  runMessage msg (LeoDeLuca attrs) = LeoDeLuca <$> runMessage msg attrs
