module Arkham.Treachery.Cards.Snakescourge (snakescourge) where

import Arkham.Ability
import Arkham.Campaigns.TheForgottenAge.Helpers
import Arkham.Helpers.Modifiers
import Arkham.Matcher
import Arkham.Placement
import Arkham.Treachery.Cards qualified as Cards
import Arkham.Treachery.Import.Lifted

newtype Snakescourge = Snakescourge TreacheryAttrs
  deriving anyclass IsTreachery
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

snakescourge :: TreacheryCard Snakescourge
snakescourge = treachery Snakescourge Cards.snakescourge

instance HasModifiersFor Snakescourge where
  getModifiersFor (Snakescourge a) = case a.placement of
    InThreatArea iid -> modifySelect a (assetControlledBy iid <> NonWeaknessAsset <> #item) [Blank]
    _ -> pure ()

instance HasAbilities Snakescourge where
  getAbilities (Snakescourge a) = [restricted a 1 (InThreatAreaOf You) $ forced $ RoundEnds #when]

instance RunMessage Snakescourge where
  runMessage msg t@(Snakescourge attrs) = runQueueT $ case msg of
    Revelation iid (isSource attrs -> True) -> do
      placeInThreatArea attrs iid
      whenM (getIsPoisoned iid) (gainSurge attrs)
      pure t
    UseCardAbility iid source 1 _ _ | isSource attrs source -> do
      toDiscardBy iid (toAbilitySource attrs 1) attrs
      pure t
    _ -> Snakescourge <$> liftRunMessage msg attrs
