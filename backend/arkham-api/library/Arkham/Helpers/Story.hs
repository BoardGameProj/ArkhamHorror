module Arkham.Helpers.Story where

import Arkham.Prelude

import Arkham.Card
import Arkham.Classes.HasGame
import Arkham.Classes.HasQueue
import Arkham.Helpers.Window
import Arkham.Id
import Arkham.Message
import Arkham.Window qualified as Window

readStory
  :: (CardGen m, HasQueue Message m, HasGame m, AsId a, IdOf a ~ LocationId)
  => InvestigatorId
  -> a
  -> CardDef
  -> m ()
readStory iid (asId -> lid) storyDef = do
  let (whenWindowMsg, _, afterWindowMsg) = frame (Window.FlipLocation iid lid)
  storyCard <- genCard storyDef
  pushAll [whenWindowMsg, afterWindowMsg, ReadStory iid storyCard ResolveIt Nothing]
