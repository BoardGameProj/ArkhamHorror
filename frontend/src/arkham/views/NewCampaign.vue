<script lang="ts" setup>
import { watch, ref, computed, onMounted } from 'vue'
import { useUserStore } from '@/stores/user'
import { useRoute } from 'vue-router'
import type { User } from '@/types'
import { useRouter } from 'vue-router'
import * as Arkham from '@/arkham/types/Deck'
import { fetchDecks, newGame } from '@/arkham/api'
import { imgsrc } from '@/arkham/helpers'
import type { Difficulty } from '@/arkham/types/Difficulty'

import campaignJSON from '@/arkham/data/campaigns.json'
import scenarioJSON from '@/arkham/data/scenarios'
import sideStoriesJSON from '@/arkham/data/side-stories.json'

const store = useUserStore()
const currentUser = computed<User | null>(() => store.getCurrentUser)
const route = useRoute();
const queryParams = route.query;

onMounted(async () => {
  if (queryParams.alpha !== undefined) {
    localStorage.setItem('alpha', 'true')
  }
})

const alpha = computed(() => {
  return queryParams.alpha !== undefined || localStorage.getItem('alpha') === 'true'
})

type GameMode = 'Campaign' | 'SideStory'

const gameMode = ref<GameMode>('Campaign')

const includeTarotReadings = ref(false)

const scenarios = computed(() => scenarioJSON.filter((s) =>
  s.beta || s.alpha
    ? currentUser.value && currentUser.value.beta
    : true
))

const sideStories = computed(() => sideStoriesJSON.filter((s) =>
  s.beta
    ? currentUser.value && currentUser.value.beta
    : true
))

const dev = import.meta.env.PROD ? false : true

const campaigns = computed(() => campaignJSON.filter((c) => {
  if (c.dev && !dev && !alpha.value) return false

  return c.beta || c.alpha
    ? currentUser.value && currentUser.value.beta
    : true
}))

const difficulties = computed<Difficulty[]>(() => {
  if(gameMode.value === 'SideStory') {
    const sideStoryScenario = sideStories.value.find((c) => c.id === selectedScenario.value)

    if (sideStoryScenario && sideStoryScenario.standaloneDifficulties) {
      return sideStoryScenario.standaloneDifficulties as Difficulty[]
    }

    return []
  }

  return ['Easy', 'Standard', 'Hard', 'Expert']
})

const router = useRouter()
const decks = ref<Arkham.Deck[]>([])
const ready = ref(false)
const playerCount = ref(1)

type MultiplayerVariant = 'WithFriends' | 'TrueSolo'

type CampaignType = 'FullCampaign' | 'PartialCampaign' | 'Standalone'

const selectedDifficulty = ref<Difficulty>('Easy')
const deckIds = ref<(string | null)[]>([null, null, null, null])
const fullCampaign = ref<CampaignType>('FullCampaign')
const selectedCampaign = ref<string | null>(null)
const selectedScenario = ref<string | null>(null)
const campaignName = ref<string | null>(null)
const multiplayerVariant = ref<MultiplayerVariant>('WithFriends')
const returnTo = ref(false)

const campaignScenarios = computed(() => selectedCampaign.value
  ? scenarios.value.filter((s) => s.campaign == selectedCampaign.value)
  : []
)

const selectCampaign = (campaignId: string) => {
  selectedCampaign.value = campaignId,
  selectedScenario.value = null
}

watch(
  difficulties,
  async (newDifficulties) => selectedDifficulty.value = newDifficulties[0]
)

fetchDecks().then((result) => {
  decks.value = result;
  ready.value = true;
})

const selectedCampaignReturnToId = computed(() => {
  const campaign = campaigns.value.find((c) => c.id === selectedCampaign.value);
  return campaign?.returnToId
})

const disabled = computed(() => {
  if (fullCampaign.value === 'Standalone' || gameMode.value === 'SideStory') {
    return !(scenario.value && currentCampaignName.value)
  } else {
    const mcampaign = campaigns.value.find((campaign) => campaign.id === selectedCampaign.value);
    return !(mcampaign && currentCampaignName.value)
  }
})

const defaultCampaignName = computed(() => {
  if (gameMode.value === 'Campaign' && campaign.value) {
    const returnToPrefix = returnTo.value ? "Return to " : ""
    return `${returnToPrefix}${campaign.value.name}`;
  }

  if (fullCampaign.value === 'Standalone' && scenario.value) {
    const returnToPrefix = returnTo.value ? "Return to " : ""
    return `${returnToPrefix}${scenario.value.name}`;
  }

  if (gameMode.value === 'SideStory' && scenario.value) {
    return `${scenario.value.name}`;
  }

  return '';
})

const currentCampaignName = computed(() => {
  return campaignName.value && campaignName.value !== ''
    ? campaignName.value
    : defaultCampaignName.value
})


const scenario = computed(() =>
  gameMode.value === 'SideStory'
    ? sideStories.value.find((s) => s.id === selectedScenario.value)
    : scenarios.value.find((s) => s.id === selectedScenario.value)
)

const campaign = computed(() =>
  gameMode.value === 'Campaign'
    ? campaigns.value.find((c) => c.id === selectedCampaign.value)
    : null
)

async function start() {
  if (fullCampaign.value === 'Standalone' || gameMode.value === 'SideStory') {
    if (scenario.value && currentCampaignName.value) {
      const scenarioId = returnTo.value && scenario.value.returnTo ? scenario.value.returnTo : scenario.value.id
      newGame(
        deckIds.value,
        playerCount.value,
        null,
        scenarioId,
        selectedDifficulty.value,
        currentCampaignName.value,
        multiplayerVariant.value,
        includeTarotReadings.value,
      ).then((game) => router.push(`/games/${game.id}`));
    }
  } else {
    const mcampaign = campaigns.value.find((campaign) => campaign.id === selectedCampaign.value);
    if (mcampaign && currentCampaignName.value) {
      const campaignId = returnTo.value && mcampaign.returnToId ? mcampaign.returnToId : mcampaign.id
      newGame(
        deckIds.value,
        playerCount.value,
        campaignId,
        fullCampaign.value ? null : selectedScenario.value,
        selectedDifficulty.value,
        currentCampaignName.value,
        multiplayerVariant.value,
        includeTarotReadings.value,
      ).then((game) => router.push(`/games/${game.id}`));
    }
  }
}

</script>

<template>
  <div v-if="ready" class="container">
    <transition-group name="slide">
      <div key="new-game">
        <header>
          <h2>{{$t('newGame')}}</h2>
          <slot name="cancel"></slot>
        </header>
        <form id="new-campaign" @submit.prevent="start">
          <div class="options">
            <input type="radio" v-model="gameMode" :value="'Campaign'" id="campaign"> <label for="campaign">{{$t('create.campaign')}}</label>
            <input type="radio" v-model="gameMode" :value="'SideStory'" id="sideStory"> <label for="sideStory">{{$t('create.sideStory')}}</label>
          </div>

          <template v-if="gameMode === 'SideStory'">
            <div class="scenarios">
              <div v-for="scenario in sideStories" :key="scenario.id" class="scenario" :class="{ beta: scenario.beta, alpha: scenario.alpha }">
                <img class="scenario-box" :class="{ 'selected-scenario': selectedScenario == scenario.id }" :src="imgsrc(`boxes/${scenario.id}.jpg`)" @click="selectedScenario = scenario.id">
              </div>
            </div>

            <div class="beta-warning" v-if="scenario && scenario.beta">{{$t('create.betaWarningScenario')}}</div>
          </template>
          <template v-else>
            <!-- <select v-model="selectedCampaign"> -->
              <div class="campaigns">
                <template v-for="c in campaigns" :key="c.id">
                  <div class="campaign" :class="{ beta: c.beta, alpha: c.alpha }">
                    <input type="image" class="campaign-box" :class="{ 'selected-campaign': selectedCampaign == c.id }" :src="imgsrc(`boxes/${c.id}.jpg`)" @click.prevent="selectCampaign(c.id)">
                  </div>
                </template>
              </div>

              <div class="alpha-warning" v-if="campaign && campaign.alpha">{{$t('create.alphaWarning')}}</div>
              <div class="beta-warning" v-if="campaign && campaign.beta">{{$t('create.betaWarning')}}</div>
            <!-- </select> -->
          </template>

          <template v-if="campaign !== undefined || scenario !== undefined">
            <p>{{$t('create.numberOfPlayers')}}</p>
            <div class="options">
              <input type="radio" v-model="playerCount" :value="1" id="player1" /><label for="player1">1</label>
              <input type="radio" v-model="playerCount" :value="2" id="player2" /><label for="player2">2</label>
              <input type="radio" v-model="playerCount" :value="3" id="player3" /><label for="player3">3</label>
              <input type="radio" v-model="playerCount" :value="4" id="player4" /><label for="player4">4</label>
            </div>
            <transition name="slide">
              <div v-if="playerCount > 1" class="options">
                <input type="radio" v-model="multiplayerVariant" value="WithFriends" id="friends" /><label for="friends">{{$t('create.withFriends')}}</label>
                <input type="radio" v-model="multiplayerVariant" value="Solo" id="solo" /><label for="solo">{{$t('create.multihandedSolo')}}</label>
              </div>
            </transition>


            <div v-if="(gameMode === 'Campaign' || fullCampaign === 'Standalone') && selectedCampaign && selectedCampaignReturnToId" class="options">
              <input type="radio" v-model="returnTo" :value="false" id="normal"> <label for="normal">{{$t('create.normal')}}</label>
              <input type="radio" v-model="returnTo" :value="true" id="returnTo"> <label for="returnTo">{{$t('create.returnTo')}}</label>
            </div>

            <div v-if="gameMode === 'Campaign' && campaign" class="options">
              <input type="radio" v-model="fullCampaign" :value="'FullCampaign'" id="full"> <label for="full">{{$t('create.fullCampaign')}}</label>
              <input type="radio" v-model="fullCampaign" :value="'Standalone'" id="standalone"> <label for="standalone">{{$t('create.standalone')}}</label>
              <template v-if="campaign.settings">
                <input type="radio" v-model="fullCampaign" :value="'PartialCampaign'" id="partial"> <label for="partial">{{$t('create.partialCampaign')}}</label>
              </template>
            </div>

            <template v-if="['Standalone', 'PartialCampaign'].includes(fullCampaign) && selectedCampaign">
              <div class="scenarios">
                <div v-for="scenario in campaignScenarios" :key="scenario.id">
                  <img class="scenario-box" :class="{ 'selected-scenario': selectedScenario == scenario.id }" :src="imgsrc(`boxes/${scenario.id}.jpg`)" @click="selectedScenario = scenario.id">
                </div>
              </div>
            </template>

            <p>{{$t('create.difficulty')}}</p>
            <div class="options">
              <template v-for="difficulty in difficulties" :key="difficulty">
                <input
                  type="radio"
                  v-model="selectedDifficulty"
                  :value="difficulty"
                  :checked="difficulty === selectedDifficulty"
                  :id="`difficulty${difficulty}`"
                />
                <label :for="`difficulty${difficulty}`">{{$t('create.'+difficulty)}}</label>
              </template>
            </div>

            <p>{{$t('create.includeTarotReadings')}}</p>
            <div class="options">
              <input
                type="radio"
                v-model="includeTarotReadings"
                :value="false"
                :checked="!includeTarotReadings"
                id="tarotNo"
              />
              <label for="tarotNo">{{$t('No')}}</label>
              <input
                type="radio"
                v-model="includeTarotReadings"
                :value="true"
                :checked="includeTarotReadings"
                id="tarotYes"
              />
              <label for="tarotYes">{{$t('Yes')}}</label>
            </div>

            <div>
              <p>{{$t('create.gameName')}}</p>
              <input type="text" v-model="campaignName" :placeholder="currentCampaignName" />
            </div>
          </template>

          <button type="submit" :disabled="disabled">{{$t('create.create')}}</button>
        </form>
      </div>
    </transition-group>
  </div>
</template>

<style lang="scss" scoped>
.container {
  min-width: 60vw;
  margin: 0 auto;
  margin-top: 20px;
}

#new-campaign {
  width: 100%;
  color: #FFF;
  border-radius: 3px;
  margin-bottom: 20px;
  display: grid;
  gap: 10px;
  button {
    outline: 0;
    padding: 15px;
    background: #6E8640;
    text-transform: uppercase;
    color: white;
    border: 0;
    width: 100%;
    &:hover {
      background: hsl(80, 35%, 32%);
    }
  }
  button[disabled] {
    background: #999;
    cursor: not-allowed;
    &:hover {
      background: #999;
    }
  }
  input[type=text] {
    outline: 0;
    border: 1px solid var(--background);
    padding: 15px;
    background: var(--background-dark);
    width: 100%;
    margin-bottom: 10px;
  }
  select {
    outline: 0;
    border: 1px solid #000;
    padding: 15px;
    background: #F2F2F2;
    width: 100%;
    margin-bottom: 10px;
    background-image:
      linear-gradient(45deg, transparent 50%, gray 50%),
      linear-gradient(135deg, gray 50%, transparent 50%),
      linear-gradient(to right, #ccc, #ccc);
    background-position:
      calc(100% - 25px) calc(1.3em + 2px),
      calc(100% - 20px) calc(1.3em + 2px),
      calc(100% - 3.5em) 0.5em;
    background-size:
      5px 5px,
      5px 5px,
      1px 2.5em;
    background-repeat: no-repeat;
  }
  a {
    color: #365488;
    font-weight: bolder;
  }
  p {
    margin: 0;
    padding: 0;
    text-transform: uppercase;
    text-box-trim: trim-both;
    text-box-edge: cap alphabetic;
  }
}

h2 {
  color: #cecece;
  margin-left: 10px;
  text-transform: uppercase;
  font-family: Teutonic;
  font-size: 2em;
  padding: 0;
  margin: 0;
}

.difficulties {
  display: flex;
  flex-wrap: auto;
}

input[type=radio] {
  display: none;
  /* margin: 10px; */
}

input[type=radio] + label {
  display:inline-block;
  padding: 4px 12px;
  background-color: hsl(80, 5%, 39%);
  border-color: #ddd;
  &:hover {
    background-color: hsl(80, 15%, 39%);
  }
}

input[type=radio]:checked + label {
  background: #6E8640;
}

input[type=checkbox] {
  display: none;
  /* margin: 10px; */
}

input[type=checkbox] + label {
  display:inline-block;
  padding: 4px 12px;
  background-color: hsl(80, 5%, 39%);
  &:hover {
    background-color: hsl(80, 15%, 39%);
  }

  &.invert {
    background: #6E8640;
    &:hover {
      background: #6E8640;
    }
  }
  border-color: #ddd;
}

input[type=checkbox]:checked + label {
  background: #6E8640;
  &.invert {
    background-color: hsl(80, 5%, 39%);
  }
}

input[type=image] {
  width: 100%;
}

.invert[type=checkbox] + label {
    background: #6E8640;
    &:hover {
      background: #6E8640;
    }
}

.invert[type=checkbox]:checked + label {
  background-color: hsl(80, 5%, 39%);
}

header {
  display: flex;
  align-items: center;
  justify-items: center;
  align-content: center;
  justify-content: center;

  h2 {
    flex: 1;
  }

}

.back-link {
  font-size: 2em;
  color: #ff00ff;
  text-decoration: none;
}

.options {
  display: flex;
  label {
    flex: 1;
    text-align: center;
    margin-left: 10px;
    &:nth-of-type(1) {
      margin-left: 0;
    }
  }
}

.campaigns {
  display: grid;
  gap: 10px;
  line-height: 0;
  grid-template-columns: repeat(6, auto);

  @media (max-width: 1500px) {
    grid-template-columns: repeat(3, auto);
  }

  img {
    width: 100%;
  }
}

.campaign-box:not(.selected-campaign) {
  -webkit-filter: grayscale(100%); /* Safari 6.0 - 9.0 */
  filter: grayscale(100%);
}

.scenarios {
  display: grid;
  line-height: 0;
  grid-template-columns: repeat(4, auto);
  gap: 10px;
  margin-bottom: 10px;

  img {
    width: 100%;
  }
}

.scenario-box:not(.selected-scenario) {
  -webkit-filter: grayscale(100%); /* Safari 6.0 - 9.0 */
  filter: grayscale(100%) sepia(0);
  transition: filter 1s linear;
  &:hover {
    filter: grayscale(100%) sepia(1);
    transition: filter 1s linear;
  }
}

.slide-enter-active,
.slide-leave-active {
  transition: all 0.3s ease-in-out;
}

.slide-enter-to,
.slide-leave-from {
  overflow: hidden;
  max-height: 1000px;
  opacity: 1;
}

.slide-enter-from,
.slide-leave-to {
  overflow: hidden;
  max-height: 0;
  opacity: 0;
}

.campaign, .scenario {
  position: relative;
  overflow: hidden;
  &.beta:after{
    content: "beta";
    position: absolute;
    z-index: 1070;
    width: 80px;
    height: 25px;
    background: darkgoldenrod;
    top: 7px;
    left: -20px;
    text-align: center;
    font-size: 12px;
    letter-spacing: 1px;
    font-family: sans-serif;
    text-transform: uppercase;
    font-weight: bold;
    color: white;
    line-height: 27px;
    -ms-transform:rotate(-45deg);
    -webkit-transform:rotate(-45deg);
    transform:rotate(-45deg);
  }

  &.alpha:after{
    content: "alpha";
    position: absolute;
    z-index: 1070;
    width: 80px;
    height: 25px;
    background: darkred;
    top: 7px;
    left: -20px;
    text-align: center;
    font-size: 12px;
    letter-spacing: 1px;
    font-family: sans-serif;
    text-transform: uppercase;
    font-weight: bold;
    color: white;
    line-height: 27px;
    -ms-transform:rotate(-45deg);
    -webkit-transform:rotate(-45deg);
    transform:rotate(-45deg);
  }
}

.beta-warning {
  font-size: 1.2em;
  text-transform: uppercase;
  padding: 10px;
  background: darkgoldenrod;
  margin-block: 10px;
}

.alpha-warning {
  font-size: 1.2em;
  text-transform: uppercase;
  padding: 10px;
  background: darkred;
  margin-block: 10px;
}
</style>
