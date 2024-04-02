module Arkham.Event.Cards.CheapShot2 (cheapShot2, cheapShot2Effect, CheapShot2 (..)) where

import Arkham.Card
import Arkham.Classes
import Arkham.Effect.Helpers
import Arkham.Effect.Runner ()
import Arkham.Effect.Types
import Arkham.EffectMetadata
import Arkham.Event.Cards qualified as Cards
import Arkham.Event.Runner
import Arkham.Fight
import Arkham.Prelude

newtype CheapShot2 = CheapShot2 EventAttrs
  deriving anyclass (IsEvent, HasModifiersFor, HasAbilities)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

cheapShot2 :: EventCard CheapShot2
cheapShot2 = event CheapShot2 Cards.cheapShot2

instance RunMessage CheapShot2 where
  runMessage msg e@(CheapShot2 attrs) = case msg of
    PlayThisEvent iid eid | eid == toId attrs -> do
      chooseFight <- toMessage <$> mkChooseFight iid attrs
      pushAll [skillTestModifier attrs iid (AddSkillValue #agility), chooseFight]
      pure e
    PassedThisSkillTestBy iid (isSource attrs -> True) n | n >= 1 -> do
      when (n >= 3)
        $ push
        $ createCardEffect Cards.cheapShot2 (Just $ EffectMetaTarget (toTarget $ toCardId attrs)) attrs iid

      void $ runMaybeT $ do
        EnemyTarget eid <- MaybeT getSkillTestTarget
        lift $ push $ EnemyEvaded iid eid
      pure e
    _ -> CheapShot2 <$> runMessage msg attrs

newtype CheapShot2Effect = CheapShot2Effect EffectAttrs
  deriving anyclass (HasAbilities, IsEffect, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

cheapShot2Effect :: EffectArgs -> CheapShot2Effect
cheapShot2Effect = cardEffect CheapShot2Effect Cards.cheapShot2

instance RunMessage CheapShot2Effect where
  runMessage msg e@(CheapShot2Effect attrs@EffectAttrs {..}) = case msg of
    EndTurn iid | toTarget iid == effectTarget -> do
      case effectMetadata of
        Just (EffectMetaTarget (CardIdTarget cardId)) -> pushAll [DisableEffect effectId, ReturnToHand iid (toTarget cardId)]
        _ -> error "invalid meta target"
      pure e
    _ -> CheapShot2Effect <$> runMessage msg attrs
