module Arkham.Asset.Assets.Backpack (backpack) where

import Arkham.Ability
import Arkham.Asset.Cards qualified as Cards
import Arkham.Asset.Import.Lifted
import Arkham.Helpers.Modifiers (ModifierType (..), controllerGets, getAdditionalSearchTargets)
import Arkham.Matcher hiding (PlaceUnderneath, PlayCard)
import Arkham.Strategy

newtype Backpack = Backpack AssetAttrs
  deriving anyclass IsAsset
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

backpack :: AssetCard Backpack
backpack = asset Backpack Cards.backpack

instance HasModifiersFor Backpack where
  getModifiersFor (Backpack a) = controllerGets a (AsIfInHand <$> a.cardsUnderneath)

instance HasAbilities Backpack where
  getAbilities (Backpack a) = [restricted a 1 ControlsThis $ freeReaction $ AssetEntersPlay #after (be a)]

instance RunMessage Backpack where
  runMessage msg a@(Backpack attrs) = runQueueT $ case msg of
    UseThisAbility iid (isSource attrs -> True) 1 -> do
      let matcher = basic $ NonWeakness <> oneOf [#item, #supply]
      search iid (attrs.ability 1) iid [fromTopOfDeck 6] matcher (defer attrs IsNotDraw)
      pure a
    SearchFound iid (isTarget attrs -> True) _ [] -> do
      chooseOne iid [Label "No Cards Found" []]
      pure a
    SearchFound iid (isTarget attrs -> True) _ cards -> do
      additionalTargets <- getAdditionalSearchTargets iid
      chooseUpToN
        iid
        (3 + additionalTargets)
        "Done choosing cards"
        [targetLabel c [PlaceUnderneath (toTarget attrs) [c]] | c <- cards]
      pure a
    SearchNoneFound iid (isTarget attrs -> True) -> do
      chooseOne iid [Label "No Cards Found" []]
      pure a
    InitiatePlayCard iid card _ _ windows _ | controlledBy attrs iid && card `elem` attrs.cardsUnderneath -> do
      let remaining = deleteFirstMatch (== card) attrs.cardsUnderneath
      when (null remaining) $ toDiscardBy iid attrs attrs
      costModifier attrs iid (AsIfInHandForPlay card.id)
      push $ PlayCard iid card Nothing NoPayment windows True
      pure $ Backpack $ attrs & cardsUnderneathL .~ remaining
    ResolvedCard _ c | c.id == attrs.cardId -> do
      when (null attrs.cardsUnderneath) $ toDiscard attrs attrs
      pure a
    _ -> do
      let hadCards = notNull attrs.cardsUnderneath
      result <- liftRunMessage msg attrs
      when (hadCards && null result.cardsUnderneath) $ toDiscard attrs attrs
      pure $ Backpack result
