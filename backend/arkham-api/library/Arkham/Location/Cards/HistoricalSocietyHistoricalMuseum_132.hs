module Arkham.Location.Cards.HistoricalSocietyHistoricalMuseum_132 (
  historicalSocietyHistoricalMuseum_132,
  HistoricalSocietyHistoricalMuseum_132 (..),
) where

import Arkham.Prelude

import Arkham.Ability
import Arkham.Action qualified as Action
import Arkham.Classes
import Arkham.GameValue
import Arkham.Location.Cards qualified as Cards
import Arkham.Location.Helpers
import Arkham.Location.Runner
import Arkham.Matcher hiding (RevealLocation)
import Arkham.Message qualified as Msg
import Arkham.SkillType
import Arkham.Timing qualified as Timing

newtype HistoricalSocietyHistoricalMuseum_132 = HistoricalSocietyHistoricalMuseum_132 LocationAttrs
  deriving anyclass (IsLocation)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

historicalSocietyHistoricalMuseum_132
  :: LocationCard HistoricalSocietyHistoricalMuseum_132
historicalSocietyHistoricalMuseum_132 =
  location
    HistoricalSocietyHistoricalMuseum_132
    Cards.historicalSocietyHistoricalMuseum_132
    2
    (PerPlayer 1)

instance HasModifiersFor HistoricalSocietyHistoricalMuseum_132 where
  getModifiersFor (InvestigatorTarget _) (HistoricalSocietyHistoricalMuseum_132 attrs) =
    do
      mtarget <- getSkillTestTarget
      mAction <- getSkillTestAction
      case (mAction, mtarget) of
        (Just Action.Investigate, Just target)
          | isTarget attrs target ->
              pure $ toModifiers attrs [SkillCannotBeIncreased SkillIntellect]
        _ -> pure []
  getModifiersFor _ _ = pure []

instance HasAbilities HistoricalSocietyHistoricalMuseum_132 where
  getAbilities (HistoricalSocietyHistoricalMuseum_132 attrs) =
    withBaseAbilities
      attrs
      [ mkAbility attrs 1
        $ ForcedAbility
        $ EnemySpawns
          Timing.When
          (LocationWithId $ toId attrs)
          AnyEnemy
      | not (locationRevealed attrs)
      ]

instance RunMessage HistoricalSocietyHistoricalMuseum_132 where
  runMessage msg l@(HistoricalSocietyHistoricalMuseum_132 attrs) = case msg of
    UseCardAbility _ source 1 _ _
      | isSource attrs source ->
          l <$ push (Msg.RevealLocation Nothing $ toId attrs)
    _ -> HistoricalSocietyHistoricalMuseum_132 <$> runMessage msg attrs
