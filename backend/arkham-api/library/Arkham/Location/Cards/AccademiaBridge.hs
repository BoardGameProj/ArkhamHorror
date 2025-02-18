module Arkham.Location.Cards.AccademiaBridge (accademiaBridge) where

import Arkham.Ability
import Arkham.Classes
import Arkham.Direction
import Arkham.GameValue
import Arkham.Location.Cards qualified as Cards
import Arkham.Location.Runner
import Arkham.Matcher
import Arkham.Prelude

newtype AccademiaBridge = AccademiaBridge LocationAttrs
  deriving anyclass (IsLocation, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

accademiaBridge :: LocationCard AccademiaBridge
accademiaBridge =
  locationWith AccademiaBridge Cards.accademiaBridge 2 (PerPlayer 1)
    $ connectsToL
    .~ singleton RightOf

instance HasAbilities AccademiaBridge where
  getAbilities (AccademiaBridge attrs) =
    extendRevealed1 attrs $ mkAbility attrs 1 $ forced $ Leaves #after You (be attrs)

instance RunMessage AccademiaBridge where
  runMessage msg l@(AccademiaBridge attrs) = case msg of
    UseCardAbility iid source 1 _ _ | isSource attrs source -> do
      push $ LoseResources iid (toAbilitySource attrs 1) 2
      pure l
    _ -> AccademiaBridge <$> runMessage msg attrs
