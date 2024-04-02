module Arkham.Evade (module Arkham.Evade, module Arkham.Evade.Types) where

import Arkham.Classes.HasGame
import Arkham.Evade.Types
import Arkham.Id
import Arkham.Matcher
import Arkham.Prelude
import Arkham.SkillType
import Arkham.Source

withSkillType :: SkillType -> ChooseEvade -> ChooseEvade
withSkillType skillType chooseEvade = chooseEvade {chooseEvadeSkillType = skillType}

mkChooseEvade :: (Sourceable source, HasGame m) => InvestigatorId -> source -> m ChooseEvade
mkChooseEvade iid source =
  pure
    $ ChooseEvade
      { chooseEvadeInvestigator = iid
      , chooseEvadeEnemyMatcher = AnyEnemy
      , chooseEvadeSource = toSource source
      , chooseEvadeTarget = Nothing
      , chooseEvadeSkillType = #combat
      , chooseEvadeIsAction = False
      }

mkChooseEvadeMatch
  :: (Sourceable source, HasGame m) => InvestigatorId -> source -> EnemyMatcher -> m ChooseEvade
mkChooseEvadeMatch iid source matcher = do
  chooseEvade <- mkChooseEvade iid source
  pure $ chooseEvade {chooseEvadeEnemyMatcher = matcher}
