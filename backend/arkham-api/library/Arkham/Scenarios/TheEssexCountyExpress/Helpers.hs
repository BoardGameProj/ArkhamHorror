module Arkham.Scenarios.TheEssexCountyExpress.Helpers where

import Arkham.Prelude

import Arkham.Classes
import Arkham.Classes.HasGame
import Arkham.Direction
import Arkham.Id
import Arkham.Matcher

leftmostLocation :: HasGame m => LocationId -> m LocationId
leftmostLocation lid = do
  mlid' <- selectOne $ LocationInDirection LeftOf $ LocationWithId lid
  maybe (pure lid) leftmostLocation mlid'
