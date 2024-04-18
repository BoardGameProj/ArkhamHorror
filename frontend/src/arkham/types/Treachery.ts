import { JsonDecoder } from 'ts.data.json';
import { Target, targetDecoder } from '@/arkham/types/Target';
import { Tokens, tokensDecoder } from '@/arkham/types/Token';
import { ChaosToken, chaosTokenDecoder } from '@/arkham/types/ChaosToken';

export type TreacheryPlacement =
  { tag: "TreacheryAttachedTo", contents: Target }
  | { tag: "TreacheryInHandOf", contents: string }
  | { tag: "TreacheryTopOfDeck", contents: string }
  | { tag: "TreacheryNextToAgenda" }
  | { tag: "TreacheryLimbo" }
  | { tag: "TreacheryInSkillTest" }

export const treacheryPlacementDecoder = JsonDecoder.oneOf<TreacheryPlacement>(
  [ JsonDecoder.object({ tag: JsonDecoder.isExactly('TreacheryAttachedTo'), contents: targetDecoder }, 'TreacheryAttachedTo')
  , JsonDecoder.object({ tag: JsonDecoder.isExactly('TreacheryInHandOf'), contents: JsonDecoder.string }, 'TreacheryInHandOf')
  , JsonDecoder.object({ tag: JsonDecoder.isExactly('TreacheryTopOfDeck'), contents: JsonDecoder.string }, 'TreacheryTopOfDeck')
  , JsonDecoder.object({ tag: JsonDecoder.isExactly('TreacheryNextToAgenda') }, 'TreacheryNextToAgenda')
  , JsonDecoder.object({ tag: JsonDecoder.isExactly('TreacheryLimbo') }, 'TreacheryLimbo')
  , JsonDecoder.object({ tag: JsonDecoder.isExactly('TreacheryInSkillTest') }, 'TreacheryInSkillTest')
  ], 'TreacheryPlacement')

export type Treachery = {
  id: string;
  cardId: string;
  cardCode: string;
  tokens: Tokens;
  placement: TreacheryPlacement;
  sealedChaosTokens: ChaosToken[];
}

export const treacheryDecoder = JsonDecoder.object<Treachery>({
  id: JsonDecoder.string,
  cardId: JsonDecoder.string,
  cardCode: JsonDecoder.string,
  tokens: tokensDecoder,
  placement: treacheryPlacementDecoder,
  sealedChaosTokens: JsonDecoder.array<ChaosToken>(chaosTokenDecoder, 'ChaosToken[]'),
}, 'Treachery');
