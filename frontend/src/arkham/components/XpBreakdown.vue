<script setup lang="ts">

import { replaceIcons } from '@/arkham/helpers';
import { handleI18n } from '@/arkham/i18n';
import { computed } from 'vue'
import scenarios from '@/arkham/data/scenarios'
import { XpEntry } from '@/arkham/types/Xp'
import { CampaignStep } from '@/arkham/types/CampaignStep'
import { Game } from '@/arkham/types/Game'
import { useI18n } from 'vue-i18n';

const { t } = useI18n()

const props = defineProps<{
  game: Game
  step: CampaignStep
  entries: XpEntry[]
  playerId?: string
  showAll: bool
}>()

// need to drop the first letter of the scenario code
const name = computed(() => {
  if (props.step.tag === 'ScenarioStep') {
    const scenarioId = props.step.contents.slice(1)
    const result = scenarios.find((s) => s.id === scenarioId || (s.returnTo && s.returnTo === scenarioId))
    if (result && result.returnTo && result.returnTo === scenarioId) {
      return result.returnToName
    }
    return result?.name || "Unknown Scenario"
  }

  if (props.step.tag === 'InterludeStep') {
    return `Interlude ${props.step.contents}`
  }

  if (props.step.tag === 'CheckpointStep') {
    return `Checkpoint ${props.step.contents}`
  }

  if (props.step.tag === 'ResupplyPoint') {
    return "Resupply Point"
  }

  if (props.step.tag === 'PrologueStep') {
    // This is a lie, we might need to split this out somehow
    return "Deck Creation"
  }

  return "Unknown step: " + props.step.tag
})

const unspendableXp = computed(() => {
  if (!props.game.campaign?.meta?.bonusXp) return null;

  if (props.step.tag === 'ScenarioStep') {
    const scenarioId = props.step.contents.slice(1)
    const investigator = Object.entries(props.game.investigators).find(([,p]) => p.playerId === props.playerId)
    if (!investigator) return null
    if (scenarioId == "53028") return props.game.campaign.meta.bonusXp[investigator[0]] || null
  }

  return null
})

const allGainXp = computed(() => {
  return props.entries.filter((entry: XpEntry) => entry.tag === 'AllGainXp')
})

const allVictoryDisplay = computed(() => {
  return allGainXp.value.filter((entry: XpEntry) => entry.details.source === 'XpFromVictoryDisplay')
})

const totalVictoryDisplay = computed(() => {
  return allVictoryDisplay.value.reduce((acc, entry) => acc + entry.details.amount, 0)
})

const perInvestigator = computed(() => {
  return Object.entries(props.game.investigators).map(([id,investigator]) => {
    if (!props.showAll && props.playerId && investigator.playerId !== props.playerId) {
      return [id, [], 0]
    }
    const gains = props.entries.filter((entry: XpEntry) => entry.tag === 'InvestigatorGainXp' && entry.investigator === id)
    const losses = props.entries.filter((entry: XpEntry) => entry.tag === 'InvestigatorLoseXp' && entry.investigator === id)

    let total = gains.reduce((acc, entry) => acc + entry.details.amount, 0) + losses.reduce((acc, entry) => acc + entry.details.amount, 0)

    return [investigator.name.title, [...gains, ...losses], total]
  }).filter(([_, xp,]) => xp.length > 0)
})

const scenarioTotal = computed(() => {
  return perInvestigator.value.reduce((acc, [, , total]) => acc + total, 0) + totalVictoryDisplay.value
})

function format(s: string) {
  const body = s.startsWith("$") ? handleI18n(s, t) : s
  return replaceIcons(body).replace(/_([^_]*)_/g, '<b>$1</b>')
}

</script>

<template>
  <div class="breakdown column box">
    <header class="breakdown-header"><h2 class="title">{{name}}</h2><span class="amount" :class="{ 'amount--negative': scenarioTotal < 0 }">{{ $t('upgrade.xp', {total: scenarioTotal}) }}</span></header>
    <div class="sections">
      <section class="box column group" v-if="unspendableXp">
        <header class="entry-header"><h3>{{ $t('upgrade.unspendableXp') }}</h3><span class="amount unspendable">{{ unspendableXp }}</span></header>
      </section>
      <section class="box column group" v-if="totalVictoryDisplay > 0">
        <header class="entry-header"><h3>{{ $t('upgrade.victoryDisplay') }}</h3><span class="amount" :class="{ 'amount--negative': totalVictoryDisplay < 0 }">{{ $t('upgrade.xp', {total: totalVictoryDisplay}) }}</span></header>
        <div class="column">
          <div v-for="(entry, idx) in allVictoryDisplay" :key="idx" class="box entry">
            <span>{{entry.details.sourceName}}</span>
            <span class="amount">+{{entry.details.amount}}</span>
          </div>
        </div>
      </section>
      <section class="box column group" v-for="([name, entries, total]) in perInvestigator" :key="name">
        <header class="entry-header"><h3>{{name}}</h3><span class="amount" :class="{ 'amount--negative': total < 0 }">{{ $t('upgrade.xp', {total: total}) }}</span></header>
        <div v-for="(entry, idx) in entries" :key="idx" class="box entry">
          <span v-html="format(entry.details.sourceName)"></span> 
          <span v-if="entry.tag !== 'InvestigatorLoseXp'" class="amount">+{{entry.details.amount}}</span>
          <span v-if="entry.tag === 'InvestigatorLoseXp'" class="amount amount--negative">{{entry.details.amount}}</span>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped lang="scss">
.breakdown {
  width: 100%;
}

h3 {
  font-size: 1.3em;
}

span {
  overflow-wrap: break-word;
  word-break: break-word;
  white-space: normal;
  hyphens:auto;
}

.breakdown-header {
  display: flex;
  gap: 10px;
  margin-top: 10px;

  .amount {
    margin-left: auto;
    min-width: 1.5em;
    padding: 0 5px;
    display: flex;
    justify-content: center;
    align-items: center;
    background: var(--spooky-green);
    color: white;
    border-radius: 3px;
    &--negative {
      background: darkred;
    }
  }
}

.unspendable {
  background: teal !important;
}

.entry-header {
  display: flex;
  gap: 10px;

  .amount {
    margin-left: auto;
    min-width: 1.5em;
    padding: 0 5px;
    display: flex;
    justify-content: center;
    align-items: center;
    background: var(--spooky-green);
    color: white;
    border-radius: 3px;
    &--negative {
      background: darkred;
    }
  }
}

.entry {
  background: rgba(255, 255, 255, 0.1);
  display: flex;
  gap: 10px;

  .amount {
    margin-left: auto;
    min-width: 1.5em;
    height: 1.5em;
    display: flex;
    justify-content: center;
    align-items: center;
    background: var(--spooky-green);
    color: white;
    border-radius: 3px;
    &--negative {
      background: darkred;
    }
  }
}

.group {
  background: rgba(0, 0, 0, 0.3);
}

.sections {
  display: flex;
  gap: 10px;
  section {
    flex: 1;
    height: fit-content;
  }
  @media (max-width: 800px) and (orientation: portrait) {
      flex-direction: column;
  }
}
</style>
