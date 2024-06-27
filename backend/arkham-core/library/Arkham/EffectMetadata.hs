module Arkham.EffectMetadata (
  EffectMetadata (..),
  effectInt,
) where

import Arkham.Prelude
import Arkham.Ability.Types
import Arkham.Card.CardCode
import Arkham.Id
import Arkham.Modifier
import Arkham.SkillType
import Arkham.Target

data EffectMetadata window a
  = EffectInt Int
  | EffectMessages [a]
  | EffectModifiers [Modifier]
  | EffectCardCodes [CardCode]
  | EffectMetaTarget Target
  | EffectMetaSkill SkillType
  | EffectAbility (Ability, [window])
  | EffectCost ActiveCostId
  | EffectText Text
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

effectInt :: Int -> Maybe (EffectMetadata window a)
effectInt = Just . EffectInt
