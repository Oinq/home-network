## 12) Home Assistant — Energia (Utility Meters)

### Estado atual (fonte de verdade)

Toda a medição e agregação de energia foi **consolidada em YAML**. O Home Assistant deixou de usar Utility Meters criados via UI (Helpers). Estes foram removidos após validação de continuidade de dados.

Princípios aplicados:

* **Single source of truth em YAML**
* Nenhum Utility Meter crítico é criado via UI
* `entity_id` mantidos para preservar estatísticas históricas
* Sensores de energia usam sempre `device_class: energy` e `state_class` compatível

---

### Sensores fonte (contadores acumulados)

Estes sensores representam os contadores reais e nunca devem ser apagados:

* `sensor.grid_energy_consumed_total`
* `sensor.grid_energy_exported_total`
* `sensor.victron_pv_energy`
* `sensor.victron_battery_energy`
* `sensor.victron_ac_loads_energy`
* `sensor.battery_charging_energy`
* `sensor.battery_discharging_energy`
* `sensor.gas_consumed_belgium`

---

### Utility meters ativos (definidos em YAML)

Todos definidos no ficheiro:

```
/homeassistant/packages/active/energy_meters.yaml
```

#### Rede elétrica (grid)

* `sensor.grid_energy_consumed_tariff1_daily | monthly | yearly`
* `sensor.grid_energy_consumed_tariff2_daily | monthly | yearly`
* `sensor.grid_energy_consumed_total_daily | monthly | yearly`
* `sensor.grid_energy_exported_total_daily | monthly | yearly`

#### Solar (PV)

* `sensor.pv_energy_daily | monthly | yearly`

#### Bateria

* `sensor.battery_energy_daily | monthly | yearly`
* `sensor.charging_energy_daily | monthly | yearly`
* `sensor.discharging_energy_daily | monthly | yearly`

#### Consumo AC (loads)

* `sensor.ac_loads_energy_daily | monthly | yearly`

#### EV Charger

* `sensor.ev_energy_daily | monthly | yearly`

#### Gás

* `sensor.gas_daily | monthly | yearly`
* `sensor.gas_kwh_daily | monthly | yearly`

---

### Limpeza realizada

Foram removidos **todos os Utility Meters criados via UI** (Helpers), identificáveis por:

* nomes com espaços (ex: "Battery Energy Daily")
* ausência do estado **Unmanageable**

Os meters YAML herdaram corretamente as estatísticas históricas (tabela `statistics`), visível na UI como **"5-minute aggregated"**.

---

### Regra operacional (energia)

* Nunca criar Utility Meters via UI
* Qualquer novo meter deve ser adicionado em `energy_meters.yaml`
* Antes de apagar entidades de energia: confirmar `entity_id` e `state_class`
* Mudanças nesta camada devem ser refletidas neste documento

---

### Gráficos de referência

Exemplo de gráfico diário recomendado (statistics-graph):

* Grid import vs PV production
* Battery charge vs discharge

Estes gráficos usam exclusivamente sensores `_daily` e `stat_types: max`.
