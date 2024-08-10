module Arkham.Event.Cards.VoiceOfRa (
  voiceOfRa,
  VoiceOfRa (..),
) where

import Arkham.Prelude

import Arkham.Card
import Arkham.ChaosBag.RevealStrategy
import Arkham.ChaosToken
import Arkham.Classes
import Arkham.Event.Cards qualified as Cards
import Arkham.Event.Runner
import Arkham.RequestedChaosTokenStrategy
import Arkham.Taboo

newtype VoiceOfRa = VoiceOfRa EventAttrs
  deriving anyclass (IsEvent, HasModifiersFor, HasAbilities)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

voiceOfRa :: EventCard VoiceOfRa
voiceOfRa = event VoiceOfRa Cards.voiceOfRa

instance RunMessage VoiceOfRa where
  runMessage msg e@(VoiceOfRa attrs) = case msg of
    PlayThisEvent iid eid | eid == toId attrs -> do
      push $ RequestChaosTokens (toSource attrs) (Just iid) (Reveal 3) SetAside
      pure e
    RequestedChaosTokens (isSource attrs -> True) (Just iid) (map chaosTokenFace -> tokens) -> do
      send $ format (toCard attrs) <> " drew " <> toSentence (map chaosTokenLabel tokens)
      push $ ResetChaosTokens (toSource attrs)
      let valid =
            if tabooed TabooList21 attrs
              then isSymbolChaosToken
              else (`elem` [Skull, Cultist, Tablet, ElderThing, AutoFail])
      let n = count valid tokens
      push $ TakeResources iid (1 + (2 * n)) (toSource attrs) False
      player <- getPlayer iid
      push $ chooseOne player [Label "Continue" []]
      pure e
    _ -> VoiceOfRa <$> runMessage msg attrs
