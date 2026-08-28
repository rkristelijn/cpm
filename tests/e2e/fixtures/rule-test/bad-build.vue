<script setup>
import { reactive, ref, defineProps } from 'vue';

// BUILD-011: props destructuring
const { name, age } = defineProps(['name', 'age']);

// BUILD-012: reactive reassign with let
let state = reactive({ count: 0 });

// BUILD-013: this in setup
console.log(this.$route);

// BUILD-014: prop mutation
props.name = 'changed';
</script>
