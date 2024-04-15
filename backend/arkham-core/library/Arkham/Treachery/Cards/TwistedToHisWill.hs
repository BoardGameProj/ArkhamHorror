module Arkham.Treachery.Cards.TwistedToHisWill (
  twistedToHisWill,
  TwistedToHisWill (..),
) where

import Arkham.Prelude

import Arkham.Classes
import Arkham.Game.Helpers
import Arkham.SkillType
import Arkham.Treachery.Cards qualified as Cards
import Arkham.Treachery.Runner

newtype TwistedToHisWill = TwistedToHisWill TreacheryAttrs
  deriving anyclass (IsTreachery, HasModifiersFor, HasAbilities)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

twistedToHisWill :: TreacheryCard TwistedToHisWill
twistedToHisWill = treachery TwistedToHisWill Cards.twistedToHisWill

instance RunMessage TwistedToHisWill where
  runMessage msg t@(TwistedToHisWill attrs) = case msg of
    Revelation iid source | isSource attrs source -> do
      doomCount <- getDoomCount
      push
        $ if doomCount > 0
          then RevelationSkillTest iid source SkillWillpower (SkillTestDifficulty DoomCountCalculation)
          else gainSurge attrs
      pure t
    FailedSkillTest iid _ (isSource attrs -> True) SkillTestInitiatorTarget {} _ _ ->
      do
        pushAll
          [ toMessage $ randomDiscard iid attrs
          , toMessage $ randomDiscard iid attrs
          ]
        pure t
    _ -> TwistedToHisWill <$> runMessage msg attrs
