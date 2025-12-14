<template>
  <div class="card">
    <h1 class="title">Kubernetes Example UI</h1>
    <p class="subtitle">
      Chiama l'API Go deployata nel cluster. Inserisci un nome e premi invia.
    </p>
    <div class="input-row">
      <input
        v-model="name"
        type="text"
        placeholder="Il tuo nome"
        @keyup.enter="fetchGreeting"
      />
      <button @click="fetchGreeting">Invia</button>
    </div>
    <div v-if="loading" class="response">Caricamento...</div>
    <div v-else-if="message" class="response">{{ message }}</div>
    <div v-else-if="error" class="response" style="color: #b42318">{{ error }}</div>
  </div>
</template>

<script setup>
import { ref } from "vue";

const name = ref("");
const message = ref("");
const error = ref("");
const loading = ref(false);

async function fetchGreeting() {
  loading.value = true;
  error.value = "";
  message.value = "";
  try {
    const url = name.value
      ? `/api/greet?name=${encodeURIComponent(name.value)}`
      : "/api/greet";
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    message.value = data.message;
  } catch (err) {
    error.value = `Errore: ${err.message}`;
  } finally {
    loading.value = false;
  }
}
</script>
