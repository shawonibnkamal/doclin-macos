<script setup>
import { ref } from 'vue'
const selected = ref('dictation')
const examples = [
  { id: 'dictation', label: 'Dictation', image: '/images/doclin-app.png', alt: 'Doclin with two example dictations ready to copy or edit' },
  { id: 'updates', label: 'Spoken updates', image: '/images/doclin-agents.png', alt: 'Doclin with example spoken updates from Codex and Claude Code' }
]
</script>

<template>
  <section class="product-preview" aria-label="See Doclin in action">
    <div class="preview-selector" role="group" aria-label="Choose a screenshot">
      <button v-for="example in examples" :key="example.id" type="button"
        :aria-pressed="selected === example.id" @click="selected = example.id">
        {{ example.label }}
      </button>
    </div>
    <div v-for="example in examples" v-show="selected === example.id" :key="example.id">
      <img class="app-shot" :src="example.image" :alt="example.alt" width="1400" height="1304" />
    </div>
    <p class="preview-caption">{{ selected === 'dictation' ? 'Speak naturally. Copy or edit your words.' : 'Hear when Codex or Claude Code finishes a task.' }} <span>Sample content.</span></p>
  </section>
</template>
