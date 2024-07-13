module Arkham.Message.Lifted.Choose where

import Arkham.Classes.HasQueue
import Arkham.Id
import Arkham.Message (Message)
import Arkham.Message.Lifted
import Arkham.Prelude
import Arkham.Question
import Control.Monad.Writer.Strict

newtype ChooseT m a = ChooseT {unChooseT :: WriterT [UI Message] m a}
  deriving newtype (Functor, Applicative, Monad, MonadWriter [UI Message], MonadTrans, MonadIO)

runChooseT :: ReverseQueue m => ChooseT m a -> m [UI Message]
runChooseT m = execWriterT (unChooseT m)

chooseOneM :: ReverseQueue m => InvestigatorId -> ChooseT m a -> m ()
chooseOneM iid choices = do
  choices' <- runChooseT choices
  chooseOne iid choices'

labeled :: ReverseQueue m => Text -> QueueT Message m () -> ChooseT m ()
labeled label action = do
  msgs <- lift $ evalQueueT action
  tell [Label label msgs]

nothing :: Monad m => QueueT Message m ()
nothing = pure ()
