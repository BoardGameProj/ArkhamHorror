module Arkham.Location.Cards.RuinsOfCarcosaAMomentsRest (
  ruinsOfCarcosaAMomentsRest,
  RuinsOfCarcosaAMomentsRest (..),
) where

import Arkham.Prelude

import Arkham.Ability
import Arkham.Classes
import Arkham.GameValue
import Arkham.Helpers.Ability
import Arkham.Location.Cards qualified as Cards
import Arkham.Location.Runner
import Arkham.Matcher
import Arkham.Scenarios.DimCarcosa.Helpers
import Arkham.Story.Cards qualified as Story
import Arkham.Timing qualified as Timing

newtype RuinsOfCarcosaAMomentsRest = RuinsOfCarcosaAMomentsRest LocationAttrs
  deriving anyclass (IsLocation, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

ruinsOfCarcosaAMomentsRest :: LocationCard RuinsOfCarcosaAMomentsRest
ruinsOfCarcosaAMomentsRest =
  locationWith
    RuinsOfCarcosaAMomentsRest
    Cards.ruinsOfCarcosaAMomentsRest
    2
    (PerPlayer 1)
    ((canBeFlippedL .~ True) . (revealedL .~ True))

instance HasAbilities RuinsOfCarcosaAMomentsRest where
  getAbilities (RuinsOfCarcosaAMomentsRest a) =
    withBaseAbilities
      a
      [ mkAbility a 1
          $ ForcedAbility
          $ DiscoveringLastClue
            Timing.After
            You
            (LocationWithId $ toId a)
      ]

instance RunMessage RuinsOfCarcosaAMomentsRest where
  runMessage msg l@(RuinsOfCarcosaAMomentsRest attrs) = case msg of
    UseCardAbility iid source 1 _ _ | isSource attrs source -> do
      push $ InvestigatorAssignDamage iid source DamageAny 1 0
      pure l
    Flip iid _ target | isTarget attrs target -> do
      readStory iid (toId attrs) Story.aMomentsRest
      pure . RuinsOfCarcosaAMomentsRest $ attrs & canBeFlippedL .~ False
    _ -> RuinsOfCarcosaAMomentsRest <$> runMessage msg attrs
