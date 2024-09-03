module Arkham.Location.Cards.PrismaticCascade (prismaticCascade, PrismaticCascade (..)) where

import Arkham.Ability
import Arkham.Classes
import Arkham.Game.Helpers
import Arkham.GameValue
import Arkham.Label (mkLabel)
import Arkham.Location.Cards qualified as Cards (prismaticCascade)
import Arkham.Location.Runner
import Arkham.Matcher hiding (DiscoverClues)
import Arkham.Name
import Arkham.Prelude
import Arkham.Timing qualified as Timing
import Control.Monad.Extra (findM)

newtype PrismaticCascade = PrismaticCascade LocationAttrs
  deriving anyclass (IsLocation, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

prismaticCascade :: LocationCard PrismaticCascade
prismaticCascade = location PrismaticCascade Cards.prismaticCascade 2 (Static 3)

instance HasAbilities PrismaticCascade where
  getAbilities (PrismaticCascade attrs) =
    withBaseAbilities attrs
      $ [ mkAbility attrs 1
          $ ForcedAbility
          $ DiscoveringLastClue Timing.After Anyone
          $ LocationWithId
          $ toId attrs
        | locationRevealed attrs
        ]

instance RunMessage PrismaticCascade where
  runMessage msg l@(PrismaticCascade attrs) = case msg of
    Revelation iid source | isSource attrs source -> do
      push $ toMessage $ randomDiscard iid attrs
      let
        labels = [nameToLabel (toName attrs) <> tshow @Int n | n <- [1 .. 2]]
      availableLabel <- findM (selectNone . LocationWithLabel . mkLabel) labels
      case availableLabel of
        Just label -> pure . PrismaticCascade $ attrs & labelL .~ label
        Nothing -> error "could not find label"
    UseCardAbility _ (isSource attrs -> True) 1 _ _ -> do
      push $ toDiscard (toAbilitySource attrs 1) attrs
      pure l
    _ -> PrismaticCascade <$> runMessage msg attrs
