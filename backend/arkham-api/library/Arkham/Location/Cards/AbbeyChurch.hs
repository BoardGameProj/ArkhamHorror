module Arkham.Location.Cards.AbbeyChurch (abbeyChurch, AbbeyChurch (..)) where

import Arkham.Ability
import Arkham.Agenda.Sequence qualified as AS
import Arkham.Agenda.Types (Field (AgendaSequence))
import Arkham.Classes
import Arkham.GameValue
import Arkham.Location.Cards qualified as Cards
import Arkham.Location.Helpers
import Arkham.Location.Runner
import Arkham.Matcher
import Arkham.Prelude

newtype AbbeyChurch = AbbeyChurch LocationAttrs
  deriving anyclass IsLocation
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

abbeyChurch :: LocationCard AbbeyChurch
abbeyChurch =
  locationWith AbbeyChurch Cards.abbeyChurch 3 (PerPlayer 1)
    $ costToEnterUnrevealedL
    .~ GroupClueCost (PerPlayer 3) "Broken Steps"

anyDifferent :: Eq a => [a] -> Bool
anyDifferent [] = False
anyDifferent [_] = False
anyDifferent (x : y : xs) = if x /= y then True else anyDifferent (y : xs)

instance HasModifiersFor AbbeyChurch where
  getModifiersFor target (AbbeyChurch a) | a `is` target = do
    as <- map AS.agendaStep <$> selectAgg pure AgendaSequence AnyAgenda
    toModifiers a [ShroudModifier 2 | anyDifferent as]
  getModifiersFor _ _ = pure []

instance HasAbilities AbbeyChurch where
  getAbilities (AbbeyChurch attrs) =
    withRevealedAbilities
      attrs
      [mkAbility attrs 1 $ forced $ RevealLocation #after Anyone $ LocationWithId $ toId attrs]

instance RunMessage AbbeyChurch where
  runMessage msg l@(AbbeyChurch attrs) = case msg of
    UseThisAbility _ (isSource attrs -> True) 1 -> do
      let titles = ["Chœur Gothique", "Knight's Hall", "Cloister", "Chapel of St. Aubert", "Abbey Tower"]
      pushAll $ map (PlaceLocationMatching . CardWithTitle) titles
      pure l
    _ -> AbbeyChurch <$> runMessage msg attrs
