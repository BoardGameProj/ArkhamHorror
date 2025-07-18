<script lang="ts" setup>
import { watch, ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router'
import { fetchDeck, deleteDeck, fetchCards, syncDeck } from '@/arkham/api';
import { imgsrc, localizeArkhamDBBaseUrl } from '@/arkham/helpers';
import * as Arkham from '@/arkham/types/CardDef';
import type {Deck} from '@/arkham/types/Deck';
import * as DeckHelpers from '@/arkham/types/Deck';
import Prompt from '@/components/Prompt.vue'
import { useToast } from "vue-toastification";
import { useDbCardStore, ArkhamDBCard } from '@/stores/dbCards'

import sets from '@/arkham/data/sets.json'

export interface Props {
  deckId: string
}

const props = defineProps<Props>()
const router = useRouter()
const toast = useToast()
const allCards = ref<Arkham.CardDef[]>([])
const ready = ref(false)
const deleting = ref(false)
const deck = ref<Deck | null>(null)
const deckRef = ref(null)
const store = useDbCardStore()

onMounted(() => {
  if (deckRef.value !== null) {
    const el = deckRef.value
    const observer = new IntersectionObserver(
      ([e]) => e.target.classList.toggle("is-pinned", e.intersectionRatio < 1),
      { threshold: [1] }
    );

    observer.observe(el);
  }
})

const enum View {
  Image = "IMAGE",
  List = "LIST",
}

fetchCards(true).then((response) => {
  allCards.value = response.sort((a, b) => {
    if (a.art < b.art) {
      return -1
    }

    if (a.art > b.art) {
      return 1
    }

    return 0
  })
  fetchDeck(props.deckId).then((deckData) => {
    deck.value = deckData
    ready.value = true
  })
})

const image = (card: Arkham.CardDef) => imgsrc(`cards/${card.art}.avif`)
const view = ref(View.List)

const cards = computed(() => {
  if (deck.value === undefined || deck.value === null) {
    return []
  }

  return Object.entries(deck.value.list.slots).flatMap(([key, value]) => {
    if (key === "c01000") {
      return Array(value).fill({ cardCode: key, classSymbols: [], cardType: "Treachery", art: "01000", level: 0, name: { title: "Random Basic Weakness", subtitle: null }, cardTraits: [], skills: [], cost: null })
    }
    
    const result = ref<Arkham.CardDef>(allCards.value.find((c) => `c${c.art}` === key))
    const language = localStorage.getItem('language') || 'en'
    if (language === 'en') return Array(value).fill(result.value)
    
    const match: ArkhamDBCard = store.getDbCard(result.value.art)
    if (!match) return Array(value).fill(result.value)
    
    // Name
    result.value.name.title = match.name
    if (match.subname) result.value.name.subtitle = match.subname
    
    // Class
    if (match.faction_name && result.value.classSymbols.length > 0) result.value.classSymbols[0] = match.faction_name
    if (match.faction2_name && result.value.classSymbols.length > 1) {
      result.value.classSymbols[1] = match.faction2_name
      if (match.faction3_name && result.value.classSymbols.length > 2) result.value.classSymbols[2] = match.faction3_name
    }
    
    // Type
    result.value.cardType = match.type_name
    
    // Traits
    if (match.traits) result.value.cardTraits = match.traits.split('.').filter(item => item != "" && item != " ")
    
    // Done...
    return Array(value).fill(result.value)
  })
})

const cardName = (card: Arkham.CardDef) => {
  const subtitle = card.name.subtitle === null ? "" : `: ${card.name.subtitle}`

  return `${card.name.title}${subtitle}`
}

const cardCost = (card: Arkham.CardDef) => {
  if (card.cost?.tag === "StaticCost") {
    return card.cost.contents
  }

  if (card.cost?.tag === "DynamicCost") {
    return -2
  }

  if (card.cost?.tag === "DiscardAmountCost") {
    return -2
  }

  return null
}

const cardType = (card: Arkham.CardDef) => {
  switch(card.cardType) {
    case "PlayerTreacheryType":
      return "Treachery"
    case "PlayerEnemyType":
      return "Enemy"
    default:
      return card.cardType.replace(/Type$/, '')
  }
}

const cardTraits = (card: Arkham.CardDef) => {
  if (card.cardTraits.length === 0) { return '' }
  return `${card.cardTraits.join('. ')}.`
}

const levelText = (card: Arkham.CardDef) => {
  if (card.level === 0 || card.level === null) return ''
  return ` (${card.level})`
}

const cardIcons = (card: Arkham.CardDef) => {
  return card.skills.map((s) => {
    if(s.tag === "SkillIcon") {
      switch(s.contents) {
        case "SkillWillpower": return "willpower"
        case "SkillIntellect": return "intellect"
        case "SkillCombat": return "combat"
        case "SkillAgility": return "agility"
        default: return "unknown"
      }
    }

    if (s.tag == "WildIcon" || s.tag == "WildMinusIcon") {
      return "wild"
    }

    return "unknown"
  })
}

const cardSet = (card: Arkham.CardDef) => {
  const cardCode = parseInt(card.art)
  return sets.find((s) => cardCode >= s.min && cardCode <= s.max)
}

const cardSetText = (card: Arkham.CardDef) => {
  const setNumber = parseInt(card.art.slice(2,))
  const language = localStorage.getItem('language') || 'en'
  var setName = ''
  
  if (language !== 'en') {
    const match: ArkhamDBCard = store.getDbCard(card.art)
    if (match) setName = match.pack_name
  }
  
  if (!setName) {
    const set = cardSet(card)
    if (set !== null && set !== undefined) setName = set.name
  }
  
  if (setName) return `${setName} ${setNumber % 500}`
  else return "Unknown"
}

async function deleteDeckEvent() {
  if (deck.value) {
    deleteDeck(deck.value.id).then(() => {
      router.push({ name: 'Decks' })
    })
  }
}

async function sync() {
  if (deck.value) {
    syncDeck(deck.value.id).then((newData) => {
      toast.success("Deck synced successfully", { timeout: 3000 })
      deck.value = newData
    })
  }
}

const deckUrlToPage = (url: string): string => {
  // converts https://arkhamdb.com/api/public/decklist/25027
  // to https://arkhamdb.com/decklist/view/25027
  // OR
  // converts https://arkhamdb.com/api/public/deck/25027
  // to https://arkhamdb.com/deck/view/25027
  return url.replace("https://arkhamdb.com", localizeArkhamDBBaseUrl()).replace("/api/public/decklist", "/decklist/view").replace("/api/public/deck", "/deck/view")
}

const deckInvestigator = computed(() => {
  if (deck.value) {
    if (deck.value.list.meta) {
      try {
        const result = JSON.parse(deck.value.list.meta)
        if (result && result.alternate_front) {
          return result.alternate_front
        }
      } catch (e) { console.log("No parse") }
    }
    return deck.value.list.investigator_code.replace('c', '')
  }

  return null
})

const deckClass = computed(() => {
  if (deck.value) return DeckHelpers.deckClass(deck.value)
  return {}
})


watch(deckRef, (el) => {
  if (el !== null) {
    const observer = new IntersectionObserver(
      ([e]) => e.target.classList.toggle("is-pinned", e.intersectionRatio < 1),
      { threshold: [1] }
    );

    observer.observe(el);
  }
})

</script>

<template>
  <div class="container">
    <div class="results">
      <header class="deck" v-show="deck" ref="deckRef" :class="deckClass">
        <template v-if="deck">
          <img v-if="deckInvestigator" class="portrait--decklist" :src="imgsrc(`cards/${deckInvestigator}.avif`)" />
          <div class="deck--details">
            <h1 class="deck-title">{{deck.name}}</h1>
            <div class="deck--actions">
              <div class="deck--view-options">
                <button @click.prevent="view = View.List" :class="{ pressed: view == View.List }">
                  <font-awesome-icon icon="list" />
                </button>
                <button @click.prevent="view = View.Image" :class="{ pressed: view == View.Image }">
                  <font-awesome-icon icon="image" />
                </button>
              </div>
              <div class="deck--non-view-options">
                <div class="open-deck">
                  <a v-if="deck.url" :href="deckUrlToPage(deck.url)" target="_blank" rel="noreferrer noopener"><font-awesome-icon alt="View Deck in ArkhamDB" icon="external-link" /></a>
                </div>
                <div v-if="deck.url" class="sync-deck">
                  <a href="#" @click.prevent="sync"><font-awesome-icon icon="refresh" /></a>
                </div>
                <div class="deck-delete">
                  <a href="#delete" @click.prevent="deleting = true"><font-awesome-icon icon="trash" /></a>
                </div>
              </div>
            </div>
          </div>
        </template>
      </header>
      <div class="cards" v-if="view == View.Image">
        <img class="card" v-for="(card, idx) in cards" :key="idx" :src="image(card)" />
      </div>
      <table class="box" v-if="view == View.List">
        <thead>
          <tr><th>Name</th><th>Class</th><th>Cost</th><th>Type</th><th>Icons</th><th>Traits</th><th>Set</th></tr>
        </thead>
        <tbody>
          <tr v-for="(card, idx) in cards" :key="idx">
            <td>{{cardName(card)}}{{levelText(card)}}</td>
            <td>{{card.classSymbols.join(', ')}}</td>
            <td>{{cardCost(card)}}</td>
            <td>{{cardType(card)}}</td>
            <td>
              <i v-for="(icon, index) in cardIcons(card)" :key="index" :class="[icon, `${icon}-icon`]" ></i>
            </td>
            <td>{{cardTraits(card)}}</td>
            <td>{{cardSetText(card)}}</td>
          </tr>
        </tbody>
      </table>
    </div>
    <Prompt
      v-if="deleting"
      prompt="Are you sure you want to delete this deck?"
      :yes="deleteDeckEvent"
      :no="() => deleting = false"
    />
  </div>
</template>

<style scoped lang="scss">
.container {
  display: flex;
  min-width: 60vw;
  margin: 0 auto;
  margin-top: 20px;
}

.results {
  flex: 1;
}

.card {
  width: calc(100% - 20px);
  margin: 10px;
  border-radius: 10px;
  box-shadow: 1px 1px 6px rgba(0, 0, 0, 0.45);
}

.cards {
  overflow-y: auto;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  padding: 10px;
}

table.box {
  width: calc(100% - 40px);
  padding: 0;
  margin: 20px;
  border-radius: 10px;
  border-spacing: 0;
  background-color: rgba(255,255,255,0.05);
  box-shadow: 1px 1px 6px rgba(0, 0, 0, 0.45);
}

th {
  text-align: left;
}

tr td:nth-child(1){
  padding-left: 20px;
}

tr th:nth-child(1){
  padding-left: 20px;
}

tbody td {
  padding: 5px;
}

thead tr th {
  color: #aaa;
  background-color: rgba(0, 0, 0, 0.2);
  padding: 5px 5px;

  &:nth-child(1) {
    border-top-left-radius: 10px;
  }

  &:last-child {
    border-top-right-radius: 10px;
  }
}

tr {
  color: #cecece;
}

tr:nth-child(even) {
  background-color: rgba(0, 0, 0, 0.1);
}

.willpower {
  font-size: 1.5em;
  margin: 0 2px;
  color: var(--willpower);
}

.intellect {
  font-size: 1.5em;
  margin: 0 2px;
  color: var(--intellect);
}

.combat {
  font-size: 1.5em;
  margin: 0 2px;
  color: var(--combat);
}

.agility {
  font-size: 1.5em;
  margin: 0 2px;
  color: var(--agility);
}

.wild {
  font-size: 1.5em;
  margin: 0 2px;
  color: var(--wild);
}

a {
  font-weight: bold;
  color: var(--spooky-green);
  text-decoration: none;
  &:hover {
    color: var(--spooky-green)-light;
  }
}

.cycles {
  color: #999;
  overflow-y: auto;
}

button {
  border: 0;
}

i {
  font-style: normal;
}

.pressed {
  background-color: #333;
  color: white;
}

/* deck header */

.open-deck {
  justify-self: flex-end;
  align-self: flex-start;
  margin-right: 10px;
}

.sync-deck {
  justify-self: flex-end;
  align-self: flex-start;
  margin-right: 10px;
}

.deck-delete {
  justify-self: flex-end;
  align-self: flex-start;
  a {
    color: var(--title);
    &:hover {
      color: #990000;
    }
  }
}

.portrait--decklist {
  width: 200px;
  margin-right: 10px;
  border-radius: 10px;
  box-shadow: 1px 1px 6px rgba(0, 0, 0, 0.45);
}

.deck-title {
  font-weight: 800;
  font-size: 2em;
  margin: 0;
  padding: 0;
  flex: 1;
}

.deck {
  background-color: #15192C;
  color: #f0f0f0;
  margin: 0 20px;
  padding: 20px;

  &.guardian {
    background-color: var(--guardian-dark);
    background: linear-gradient(30deg, var(--guardian-extra-dark), var(--guardian-dark));
  }

  &.seeker {
    background: linear-gradient(30deg, var(--seeker-extra-dark), var(--seeker-dark));
  }

  &.rogue {
    background: linear-gradient(30deg, var(--rogue-extra-dark), var(--rogue-dark));
  }

  &.mystic {
    background: linear-gradient(30deg, var(--mystic-extra-dark), var(--mystic-dark));
  }

  &.survivor {
    background: linear-gradient(30deg, var(--survivor-extra-dark), var(--survivor-dark));
  }

  &.neutral {
    background-color: var(--neutral-dark);
    background-image: linear-gradient(30deg, var(--neutral-extra-dark), var(--neutral-dark));
  }

  /*&.survivor::after {
    content: '';
    display: block;
    width: 100%;
    height: 100%;
    position: absolute;
    inset: 0;
    background: #0000000d;
    mask-position: left top;
    mask-size: cover;
    -webkit-mask-image: url(/img/arkham/masks/survivor.svg);
    mask-image: url(/img/arkham/masks/survivor.svg);
    z-index: -1;
  }*/
  a {
    color: var(--title);
    font-weight: bolder;
    &:hover {
      color: rgba(0, 0, 0, 0.4);
    }
  }

  display: flex;

  width: calc(100% - 40px);
  box-shadow: 1px 1px 6px rgba(0, 0, 0, 0.45);
  border-radius: 10px;
  &.is-pinned {
    border-top-left-radius: 0;
    border-top-right-radius: 0;
    opacity: 0.98;
  }
  background-color: rgba(0,0,0,0.3);

  color: white;

  input {
    margin-right: 10px;
  }

  button {
    padding: 5px;
  }

  position: sticky;
  position: -webkit-sticky;
  top: -1px;

  &.is-pinned {
    background-color: rgba(28, 28, 41, 1) !important;
  }
}

.deck--details {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.deck--actions {
  display: flex;
}

.deck--view-options {
  display: flex;
  flex: 1;
}

.deck--non-view-options {
  display: flex;
  align-self: flex-end;
}
</style>
