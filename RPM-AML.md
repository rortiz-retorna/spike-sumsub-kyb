RPM - Ecosistema Monitoreo - original
Proyecto estratégico: Ecosistema Monitoreo

Versión completa basada en el Retorna Project Model y el timeline H1 2026.

Parte Negocio 1

1. Contexto

Retorna está experimentando un crecimiento significativo en complejidad operativa, número de rutas, proveedores y volumen transaccional.

A medida que la empresa escala su operación internacional, se vuelve crítico contar con un ecosistema de monitoreo financiero y de compliance que permita observar, evaluar y reaccionar ante riesgos operativos y regulatorios en tiempo real o near real-time.

Actualmente, los controles de riesgo se encuentran fragmentados entre distintos proveedores, sistemas y procesos internos, lo que dificulta la gestión integrada del riesgo.

Las capacidades actuales se distribuyen de la siguiente manera:

Identidad

KYC: MetaMap
KYB: proceso manual

Infraestructura transaccional

Custodia y ejecución de transacciones: Fireblocks

Inteligencia blockchain

Actualmente no existe un proveedor activo de blockchain intelligence

Monitoreo transaccional y gestión de casos

Ceptinel (actualmente apagado)

Datos internos de Retorna

remesas
wallets
operaciones internas

Sin una arquitectura de monitoreo integrada:

Los riesgos pueden detectarse de forma tardía
Los eventos relevantes no se correlacionan entre sistemas
La trazabilidad se pierde entre plataformas
La gestión de casos AML depende de análisis manual

Actualmente los casos y alertas deben revisarse manualmente en dashboards operativos:

https://us-east-1.quicksight.aws.amazon.com/sn/auth/signin?directory_alias=retorna-quicksight

Además, el conocimiento operativo queda distribuido entre múltiples herramientas externas y almacenamiento local, lo que genera dependencia de personas y dificulta la auditoría.

Por esta razón, Retorna necesita construir un Ecosistema de Monitoreo unificado, capaz de:

integrar señales de riesgo provenientes de múltiples fuentes
correlacionar eventos financieros e identitarios
generar alertas estructuradas
habilitar decisiones operativas auditables
Observación estratégica

Este proyecto constituye el primer paso hacia la construcción de un Motor de Compliance de Retorna.

Este motor tendrá como objetivo:

crear modelos canónicos de riesgo
desacoplar la operación de proveedores específicos
permitir conectar o reemplazar proveedores sin impacto operativo
mejorar la experiencia del cliente en el journey de cumplimiento
2. Problema definido

Actualmente los procesos de monitoreo presentan limitaciones estructurales importantes.

Fragmentación de señales de riesgo

Los eventos relevantes se generan en distintos sistemas independientes:

Fireblocks (ejecución de transacciones)
Ceptinel (monitoring / AML — actualmente deshabilitado)
Sistemas internos de Retorna (in house)
Datos almacenados en computadoras locales

Además, actualmente no existe un proveedor activo de blockchain risk intelligence (KYT).

Esta fragmentación dificulta construir una visión consolidada del riesgo financiero y operativo.

Falta de correlación entre eventos

No existe un modelo central que permita relacionar:

identidad del usuario
actividad transaccional
señales de riesgo blockchain (KYT)
alertas AML
decisiones operativas

Esto impide construir un timeline completo del riesgo por cliente o transacción, limitando la capacidad de investigación y análisis.

Gestión manual de casos AML

Actualmente gran parte del proceso depende de revisión manual.

En muchos casos:

las alertas se detectan tarde
el análisis depende completamente de revisión humana
existen más de 7.000 casos pendientes de revisión
no existe un flujo automático de creación de casos AML alineado con Circular 62 y ROS
el escalamiento no sigue reglas homogéneas
Dificultad para auditar decisiones

Las decisiones operativas de compliance (bloqueos, revisiones, aprobaciones) no siempre cuentan con:

trazabilidad clara
evidencia estructurada
registro de las señales de riesgo utilizadas

Esto genera riesgo regulatorio y operativo, especialmente frente a auditorías o requerimientos regulatorios.

3. Impacto actual (con números)

Actualmente el sistema registra el siguiente volumen de cuentas clasificadas por nivel de riesgo:

Nivel de riesgo	Cuentas
C4	196
C3	348
C2	4.322
C1	13.822
Riesgo operativo

La situación actual genera riesgos relevantes:

transacciones ejecutadas sin análisis completo de riesgo
detección tardía de wallets de alto riesgo
exposición potencial a fraude o lavado de dinero
Carga operativa

El proceso actual requiere:

revisión manual de alertas
análisis caso por caso
falta de priorización automática de riesgos
dificultad para escalar casos críticos
Riesgo regulatorio

Los reguladores financieros requieren:

monitoreo transaccional efectivo
trazabilidad completa de decisiones
evidencia documentada de investigaciones AML
capacidad de generar reportes de actividad sospechosa (SAR / ROS)

La ausencia de un ecosistema de monitoreo integrado incrementa la exposición regulatoria de la empresa.

Impacto en escalabilidad

Sin automatización del monitoreo:

el crecimiento del volumen transaccional requiere más analistas
el costo operativo aumenta proporcionalmente
la gestión del riesgo no escala al mismo ritmo que el negocio
4. Objetivo del Ecosistema de Monitoreo

El objetivo del Ecosistema de Monitoreo de Retorna es unificar y estructurar el monitoreo de riesgos financieros y regulatorios en todos los flujos operativos de la empresa.

Esto incluye el monitoreo de transacciones en:

Moneda fiat
Stablecoins / criptoactivos
Clientes individuales (KYC)
Clientes empresa (KYB)

El ecosistema debe permitir aplicar reglas de monitoreo transaccional de forma consistente, integrando señales de riesgo provenientes de múltiples fuentes.

Las principales fuentes de señal serán:

Infraestructura transaccional

Fireblocks

Blockchain intelligence

Chainalysis

Transaction monitoring y case management

Sumsub

Datos internos

Sistemas operativos de Retorna

(remesas, wallets, operaciones, eventos internos)

Alcance funcional del ecosistema

El ecosistema deberá permitir:

Monitoreo integral de transacciones
evaluación de riesgo antes de ejecutar transacciones
monitoreo posterior a la ejecución
correlación de señales de riesgo provenientes de múltiples sistemas
Integración de KYC y KYB

El sistema deberá soportar:

KYC para clientes individuales
KYB para clientes empresa

Incluyendo:

generación de links de verificación KYB para proveedores
generación de links KYB para clientes empresa
procesos KYB embebidos dentro del portal Retorna Business

Esto permitirá mejorar significativamente la experiencia de onboarding para empresas, reduciendo fricción operativa y tiempos de validación.

Motor de reglas de monitoreo

El ecosistema debe permitir aplicar reglas de monitoreo sobre:

comportamiento transaccional
actividad blockchain
patrones de riesgo AML
señales de proveedores externos

Estas reglas deberán permitir:

generación automática de alertas
priorización de riesgo
creación automática de casos AML
Base interna de datos de compliance

Un componente crítico del ecosistema será la creación de una base interna de compliance y monitoreo dentro de Retorna.

Actualmente, gran parte de la información relevante se encuentra almacenada únicamente en sistemas de terceros, lo que genera varios riesgos:

dependencia de proveedores externos
dificultad para auditorías
falta de trazabilidad histórica consolidada
limitaciones para correlacionar eventos entre sistemas

Por esta razón, el ecosistema deberá incluir una base interna que permita almacenar y correlacionar información clave, incluyendo:

identidades verificadas (KYC/KYB)
señales de riesgo
eventos transaccionales
alertas generadas
decisiones operativas de compliance
historial de investigaciones AML

Esto permitirá construir una visión consolidada del riesgo por cliente, wallet o transacción.

Justificación regulatoria y de seguridad

La necesidad de mantener registros internos estructurados de información de compliance y monitoreo se alinea con prácticas recomendadas en distintos marcos regulatorios y estándares de seguridad.

Circular 62 (Chile – UAF / AML)

Las regulaciones AML requieren que las instituciones:

mantengan registros completos de transacciones y análisis de riesgo
conserven evidencias de monitoreo y decisiones de compliance
puedan reconstruir investigaciones AML cuando sea requerido

Esto implica la necesidad de mantener trazabilidad interna de las señales utilizadas en decisiones de riesgo.

ISO 27001 (gestión de seguridad de la información)

Los controles de seguridad asociados a ISO 27001 establecen que las organizaciones deben:

mantener control sobre la información crítica
asegurar disponibilidad, integridad y trazabilidad de datos
evitar dependencia excesiva de sistemas externos para información crítica

En el contexto de compliance financiero, esto implica que la organización debe ser capaz de:

preservar información relevante
auditar eventos
reconstruir decisiones operativas
Resultado esperado

El Ecosistema de Monitoreo permitirá que Retorna:

centralice el monitoreo de riesgos financieros
correlacione señales provenientes de múltiples proveedores
automatice la detección de comportamientos sospechosos
reduzca la dependencia de procesos manuales
fortalezca el cumplimiento regulatorio
escale su operación internacional de forma segura
5. Métricas de éxito (máximo 3)
1. Cobertura del monitoreo transaccional

Mide qué porcentaje de la actividad financiera de Retorna está siendo evaluada por el ecosistema de monitoreo.

Indicadores principales:

% de transacciones monitoreadas
cobertura por tipo de flujo:
C2C
B2B
stablecoins / cripto
fiat
cobertura por proveedor
cobertura por país o ruta

Objetivo esperado:

≥ 95% de transacciones evaluadas por el sistema de monitoreo
2. Efectividad en la detección de riesgo

Evalúa la capacidad del ecosistema para identificar actividades potencialmente riesgosas.

Indicadores principales:

% de alertas generadas automáticamente
ratio de alertas relevantes vs ruido
tiempo promedio de detección de eventos sospechosos
número de señales correlacionadas por evento

Objetivo esperado:

detección automática de eventos de riesgo antes o inmediatamente después de la ejecución de la transacción
3. Gestión de casos AML

Evalúa la eficiencia del proceso de investigación y resolución de alertas.

Indicadores principales:

% de casos AML generados automáticamente
tiempo promedio de análisis de casos
% de casos resueltos dentro del SLA
backlog de casos pendientes
aging promedio de investigaciones

Objetivo esperado:

reducción significativa de revisión manual no priorizada
gestión de casos basada en priorización automática de riesgo
Métricas operativas complementarias

Adicionalmente se monitorearán métricas operativas del sistema:

número de señales de riesgo procesadas por día
número de integraciones activas (proveedores de riesgo)
volumen de eventos correlacionados
disponibilidad del sistema de monitoreo
Resultado esperado

Un ecosistema de monitoreo exitoso permitirá que Retorna:

monitoree prácticamente todas sus transacciones
detecte comportamientos sospechosos de forma automática
reduzca la dependencia de análisis manual
fortalezca la capacidad de respuesta ante riesgos financieros y regulatorios.
6. Cómo imagino el resultado (estado futuro)

Fase Actual — Arquitectura Inicial (solo KYC)

Arquitectura
User
 ↓
KYC
(Metamap)
 ↓
Wallet operations / Fiat transactions
(Fireblocks / Sistemas internos)
Controles existentes
Control	Sistema
KYC	Metamap
Custodia de wallets	Fireblocks
Operaciones fiat	Sistemas internos
Limitaciones
No existe monitoreo blockchain estructurado
Monitoreo AML para fiat desactivado
No existe AML transaccional
Alto nivel de revisión manual
Ausencia de case management centralizado

Fase 1 — Monitoring Manual (Transición Operacional)

En esta fase se introduce monitoring AML, pero gran parte de los procesos sigue siendo manual.

Se incorporan:

Sumsub para gestión AML y KYB
Chainalysis para inteligencia blockchain
procesos de revisión manual para cumplimiento.
1A — Arquitectura Fiat (proceso manual)

Las transacciones fiat se revisan posteriormente a su ejecución mediante procesos manuales de análisis AML.

User
 ↓
KYC / KYB  — Day 1
(Metamap / Sumsub)
 ↓
Fiat transaction request — Day 2
 ↓
Transaction export — Day +5
(CSV / Excel desde core system, banco o PSP)
 ↓
Manual AML review
(Sumsub portal / procesos internos)
 ↓
Compliance decision
 ↓
Normal / Hold / Block
(Account / Relationship)
 ↓
AML Case (si aplica)
(Sumsub Case Manager)
 ↓
Operations follow-up
1B — Arquitectura Cripto

Para cripto se introduce screening automático blockchain, pero la gestión de casos continúa siendo manual.

Principios
Fireblocks está integrado con Chainalysis
El screening blockchain ocurre automáticamente
El case management y monitoring AML se realiza en Sumsub
Arquitectura
User
 ↓
KYC / KYB — Day 1
(Metamap / Sumsub)
 ↓
Crypto transaction request — Day 2
 ↓
Transaction created
(Fireblocks)
 ↓
Automatic blockchain screening
(Chainalysis KYT via Fireblocks)
 ↓
Risk score
 ↓
Policy evaluation
(Fireblocks Policy Engine)
 ↓
Execute / Block
(Fireblocks)
 ↓
Transaction export — Day +5
 ↓
Manual AML review
(Sumsub portal)
 ↓
Blockchain signals
(Chainalysis via Sumsub)
 ↓
AML Case
(Sumsub Case Manager)
 ↓
Compliance decision
1C — KYB (proceso manual)

El proceso KYB se gestiona manualmente mediante el portal de Sumsub.

Company onboarding
 ↓
Compliance
(Retorna)
 ↓
KYB request
(Sumsub portal → email enviado al cliente o proveedor)
 ↓
Document submission
 ↓
Compliance review
 ↓
KYB decision
Cómo trabajan los equipos en esta fase
Compliance

Portal principal:

Sumsub

Actividades principales:

revisión KYC
verificación KYB
monitoreo AML
gestión de alertas
creación de casos AML
generación de links KYB
consolidación de evidencia para auditoría.

Además:

pueden subir transacciones manualmente para análisis AML
documentan decisiones regulatorias.
Investigaciones Blockchain

Portal:

Chainalysis Reactor / KYT

Uso:

investigación de wallets sospechosas
trazabilidad de fondos
análisis de exposición a entidades
investigaciones AML avanzadas.

Importante:

Fireblocks realiza el screening automático
Reactor se usa para investigaciones manuales
Tesorería / Operaciones

Portal principal:

Fireblocks

Uso:

aprobación de transacciones
bloqueo de operaciones
administración de vaults
monitoreo de actividad de wallets
aplicación de políticas AML.
Flujo operativo simplificado
1. Cliente inicia una operación
2. Se crea la transacción en Fireblocks
3. Chainalysis analiza automáticamente el riesgo blockchain
4. Fireblocks aplica las políticas AML
5. La transacción se ejecuta o se bloquea
6. Los datos de la transacción se exportan
7. Compliance revisa la operación en Sumsub
8. Si existe riesgo se crea un caso AML
Limitaciones de esta arquitectura
Problema	Motivo
duplicación de señales AML	Chainalysis utilizado en múltiples sistemas
procesos parcialmente manuales	carga y revisión manual en Sumsub
fragmentación de monitoreo	datos distribuidos entre herramientas
latencia en investigación	análisis AML posterior a la ejecución
trazabilidad incompleta	falta de repositorio centralizado
1D — Repositorio central de Compliance

Como parte de esta fase se propone crear:

una arquitectura centralizada para la gestión y almacenamiento de documentación de compliance, incluyendo:

evidencias AML
casos regulatorios
documentación KYC/KYB
reportes de auditoría
decisiones operacionales.

Este repositorio permitirá:

mejorar la trazabilidad
facilitar auditorías regulatorias
centralizar la gestión documental de compliance.

Fase 2 — Compliance Orchestration (transacciones automáticas, decisiones manuales)

En esta fase las transacciones ya no se cargan manualmente.

Ahora llegan automáticamente a través de integraciones con los sistemas de Retorna.

Esto incluye los distintos tipos de operación:

C2C
B2C
B2B
Wallet

Sin embargo, las decisiones operativas críticas siguen siendo manuales, especialmente:

bloqueo o desbloqueo de cuentas
bloqueo de wallets
bloqueo o aprobación de transacciones cripto

Estas acciones continúan siendo ejecutadas manualmente por el equipo de compliance u operaciones.

Arquitectura
User
 ↓
KYC / KYB
(Metamap / Sumsub)
 ↓
Transaction request
 ↓
Transaction created
(Retorna systems)
 ↓
Automatic transaction ingestion
(Sumsub / monitoring systems)
 ↓
Blockchain screening
(Chainalysis via Fireblocks)
 ↓
Risk signals
 ↓
Transaction monitoring
(Sumsub Rules Engine)
 ↓
AML Alert / Case
(Sumsub Case Manager)
 ↓
Operations review
 ↓
Manual decision
(Block / Approve / Investigate)
Qué cambia en Fase 2
Antes	Ahora
transacciones cargadas manualmente	transacciones llegan automáticamente por integración
revisión AML posterior a carga	monitoreo continuo
análisis manual inicial	análisis automático + revisión manual
Qué sigue siendo manual
Acción	Sistema
bloqueo de cuentas	operaciones / backoffice
bloqueo de wallets	Fireblocks
bloqueo de transacciones cripto	Fireblocks
decisiones AML	equipo de compliance
Flujo operativo simplificado
1. Cliente inicia una operación
2. La transacción se crea en los sistemas de Retorna
3. La transacción llega automáticamente al sistema de monitoreo
4. Chainalysis analiza riesgo blockchain
5. Sumsub genera alertas AML si corresponde
6. Compliance revisa el caso
7. Operaciones decide manualmente bloquear o aprobar
Limitaciones de esta fase
Problema	Motivo
decisiones operativas manuales	bloqueo y ejecución no automatizados
dependencia del análisis humano	revisión de alertas AML
posible latencia en decisiones	intervención manual

Fase 3 — Compliance Orchestration Automatizada (Real-time)

En esta fase el sistema evoluciona hacia un modelo completamente integrado y en tiempo real, donde las decisiones de compliance impactan directamente la ejecución operativa.

El principio central es:

Sumsub decide → Core de Retorna orquesta → Fireblocks / PSP ejecutan

Esto elimina procesos manuales y permite bloqueos, revisiones y aprobaciones en tiempo real tanto para fiat como para cripto.

Principios de la Fase 3
Decisiones AML en tiempo real
Orquestación central en el Core de Retorna
Integración directa entre sistemas de compliance y ejecución
Gestión nativa de KYB en el portal de empresas
Trazabilidad completa de decisiones regulatorias
Arquitectura general
User / Company
 ↓
KYC / KYB
(Retorna Portal → Sumsub API)
 ↓
Transaction request
 ↓
Core Retorna
(Transaction orchestration)
 ↓
Real-time risk evaluation
(Sumsub + Chainalysis signals)
 ↓
Compliance decision
 ↓
Core Retorna enforcement
 ↓
Execute / Hold / Block
(Fireblocks / Fiat PSP / Bank)
 ↓
Transaction monitoring
 ↓
AML Case (si aplica)
(Sumsub Case Manager)
Flujo de decisión en tiempo real
Transaction request
 ↓
Core Retorna
 ↓
Risk signals
(Sumsub AML + Chainalysis KYT)
 ↓
Decision
 ├─ Approve
 ├─ Hold / Review
 └─ Block
 ↓
Core enforcement
 ↓
Execution control
(Fireblocks / Fiat rails)
Arquitectura para Cripto
User
 ↓
Transaction request
 ↓
Core Retorna
 ↓
Fireblocks
 ↓
Automatic blockchain screening
(Chainalysis KYT)
 ↓
Risk signals
 ↓
Sumsub AML evaluation
 ↓
Compliance decision
 ↓
Core Retorna
 ↓
Execute / Block / Freeze wallet
(Fireblocks)

En esta fase:

bloqueos de wallet
bloqueos de transacciones
freezing de cuentas

se ejecutan automáticamente desde decisiones de compliance.

Arquitectura para Fiat
User
 ↓
Transaction request
 ↓
Core Retorna
 ↓
Pre-transaction AML check
(Sumsub)
 ↓
Risk evaluation
 ↓
Decision
 ├─ Approve
 ├─ Hold
 └─ Block
 ↓
Execution
(PSP / Bank / Payout provider)

El objetivo es que:

las decisiones AML ocurran antes de ejecutar la operación
el sistema tenga capacidad de bloqueo preventivo.
KYB integrado en portal de empresas

En esta fase el proceso KYB deja de ser manual.

El portal de empresas de Retorna genera el link KYB automáticamente.

Company onboarding
 ↓
Retorna Business Portal
 ↓
Generate KYB UI
(Sumsub API)
 ↓
Company completes verification
 ↓
Compliance review
 ↓
KYB decision
 ↓
Account activation

Beneficios:

onboarding más rápido
menor intervención manual
trazabilidad completa.
Rol del Core de Retorna

El Core se convierte en el orquestador central de compliance.

Responsabilidades:

transaction ingestion
risk signal aggregation
policy orchestration
decision enforcement
audit logging
case linkage

Esto evita que la lógica AML quede distribuida entre proveedores.

Cómo trabajan los equipos en esta fase
Compliance

Portal principal:

Sumsub

Responsabilidades:

revisión de casos AML
análisis de alertas
investigaciones regulatorias
reporting (SAR / ROS).
Investigaciones Blockchain

Portal:Chainalysis Reactor

Uso:

investigación avanzada
trazabilidad de fondos
análisis de entidades.
Operaciones / Tesorería

Portal principal:Fireblocks

Uso:

monitoreo de actividad
gestión de vaults
supervisión de operaciones.

Las decisiones críticas ahora son automatizadas por el sistema.

Beneficios de esta fase
Mejora	Impacto
decisiones AML en tiempo real	reducción de riesgo
bloqueo preventivo	evita ejecución de operaciones sospechosas
menor carga operativa	menos revisión manual
trazabilidad completa	auditoría regulatoria más simple
onboarding KYB automatizado	mejor experiencia B2B
Riesgos y desafíos
Riesgo	Mitigación
falsos positivos AML	calibración de reglas
dependencia de proveedores	core de orquestación
complejidad técnica	arquitectura modular
latencia en decisiones	caché de señales de riesgo

Fase 4 — Motor de Riesgo (Backend) + Case Manager Interno (Front-end)

En esta fase, Retorna evoluciona desde un modelo provider-led (Sumsub/Chainalysis/Fireblocks) a un modelo platform-led, donde:

el Risk Engine (backend) es propio
el Case Management (front-end + workflow) es propio
los proveedores quedan como data providers / signal providers (entradas), no como el “cerebro” ni el “sistema operativo” de AML.

Objetivo: reducir dependencia, centralizar lógica, mejorar trazabilidad y escalar a múltiples países/productos (C2C/B2C/B2B/Wallet) con reglas consistentes.

Principios de diseño
Decisión única por transacción/evento (single source of truth).
Orquestación real-time desde el Core.
Proveedores como fuentes de señales, no como motor.
Case Manager unificado para fiat + cripto + fraude + ops.
Auditabilidad end-to-end (quién decidió, por qué, con qué señales, cuándo).
Arquitectura objetivo (alto nivel)
User / Company
 ↓
KYC / KYB / PEP / Sanctions
(Sumsub / MetaMap / otros)
 ↓
Transaction request / Event
(C2C, B2C, B2B, Wallet)
 ↓
Core Retorna (Orchestrator)
 ↓
Risk Engine (Retorna)
  ├─ Reglas + scoring
  ├─ Velocity / perfilamiento
  ├─ Detección de patrones
  ├─ Enrichment (país, ruta, producto, customer tier)
  └─ Señales externas (Chainalysis, listas, bancos, etc.)
 ↓
Decision Service (Retorna)
  ├─ Approve
  ├─ Hold (Review)
  ├─ Block
  └─ Freeze (cuenta / wallet)
 ↓
Enforcement
  ├─ Cripto: Fireblocks
  └─ Fiat: PSP/Banco/Payout provider
 ↓
Case Manager (Retorna)
  ├─ Alertas
  ├─ Casos AML
  ├─ Flujos operativos
  ├─ Evidencia y comentarios
  └─ Reportes regulatorios
Componentes clave
5A) Risk Engine (backend) — qué hace
Inputs (señales)
KYC/KYB: estado, score, flags (PEP/sanctions)
Transacciones: monto, frecuencia, ruta, beneficiario, método, device/IP (si aplica)
Blockchain: risk score, exposición, entidad (Chainalysis u otro)
Fiat rails: banco/PSP feedback, rechazos, devoluciones, chargebacks (si aplica)
Listas: sanctions/PEP/watchlists internas y externas
Outputs (decisiones)
decision = APPROVE | HOLD | BLOCK | FREEZE
risk_score (0–100)
reasons[] (explicables)
required_actions[] (p.ej. “recolectar doc”, “escalar compliance”, “solicitar SoF”)
case_required = true/false
5B) Case Manager interno (front-end)
Módulos principales
Inbox de alertas (triage)
Casos (AML / fraude / ops)
Workflow configurable (SLA, niveles, escalamiento)
Evidencia (archivos, links, capturas, hash, logs)
Decisiones (approve/hold/block/freeze) con “reason codes”
Auditoría (histórico, quién, cuándo, cambios)
Reporting (export SAR/ROS/STR, según país)
Integraciones
Core/ledger (transacciones)
Fireblocks (acciones cripto: freeze/unfreeze, block/unblock)
PSP/bancos (hold/reject/cancel)
CRM/backoffice (Salesforce si aplica)
Data warehouse (para analítica y tuning)
Flujo operativo (real-time) con case interno
Event/Transaction
 ↓
Risk Engine evalúa en ms–segundos
 ↓
Si APPROVE → Core ejecuta
Si HOLD/BLOCK/FREEZE → Core aplica enforcement
 ↓
Se crea alerta/caso automático
(Case Manager Retorna)
 ↓
Analista revisa
 ↓
Analista decide (con control de permisos)
 ↓
Core aplica acción final (si cambia)
 ↓
Cierre con evidencia + log auditable
Qué cambia versus Fase 3
Tema	Fase 3 (provider-led)	Fase 4 (platform-led)
Motor de decisión	Sumsub/Fireblocks policies	Risk Engine propio
Case management	Sumsub	Retorna internal
Proveedores	“sistema operativo”	fuentes de señales
Consistencia multi-producto	media	alta
Tuning y control	limitado	total
Vendor lock-in	alto	bajo
Beneficios esperados
Menor vendor lock-in (cambias Sumsub/Chainalysis sin reescribir todo)
Reglas coherentes para C2C/B2C/B2B/Wallet
Menos latencia y menos pasos manuales
Mejor auditoría y trazabilidad end-to-end
Escala internacional (mismo core, reglas por país)
Riesgos / trade-offs
Riesgo	Trade-off	Mitigación
complejidad técnica alta	más ingeniería/QA	roadmap incremental, feature flags
riesgo regulatorio si se implementa mal	más responsabilidad interna	validación con compliance + auditoría
falsos positivos	impacto en conversión	tuning, A/B, thresholds por ruta
datos incompletos	decisiones pobres	contrato de datos + observabilidad
Criterios de éxito (KPIs)
↓ tiempo de decisión (p95) para HOLD/BLOCK
↓ manual review rate por producto/ruta
↓ false positives (casos cerrados como “no issue”)
↑ detection yield (casos verdaderos / total alertas)
↑ audit completeness (casos con evidencia completa)
↓ MTTR de casos críticos
↓ dependencia operativa de portales externos

Parte Negocio 2

7. Definition of Done del proyecto

El proyecto se considerará finalizado cuando se cumplan las siguientes condiciones:

Integraciones implementadas
Integración funcional con Sumsub para:
KYC
KYB
gestión de casos AML
Integración con Chainalysis a través de Fireblocks para el monitoreo de riesgo blockchain (KYT).
Monitoreo y alertas
Recepción y registro de señales de riesgo provenientes de Chainalysis.
Capacidad del equipo de compliance para analizar alertas y generar casos AML en Sumsub.
Definición de procedimientos operativos para revisión de alertas y decisiones de bloqueo.
Procesos operativos
Existencia de un proceso documentado para revisión de transacciones sospechosas.
Capacidad de bloquear o restringir clientes, cuentas o wallets cuando se detecte riesgo elevado.
Registro de las decisiones de compliance para auditoría y trazabilidad.
Documentación
Documentación completa de:
arquitectura de compliance
flujos operativos
responsabilidades de cada sistema y equipo.
Capacitación del equipo
El equipo de Compliance y Operaciones conoce:
cómo revisar alertas
cómo abrir casos
cómo aplicar bloqueos o revisiones.
8. Alcance del proyecto

El alcance de este proyecto incluye la implementación inicial de un ecosistema de monitoreo de riesgo para operaciones fiat y cripto en Retorna, utilizando proveedores especializados.

Incluye
Identificación y verificación
Verificación de identidad de usuarios (KYC) mediante Metamap.
Verificación de empresas (KYB) mediante Sumsub.
Monitoreo blockchain
Análisis de riesgo de transacciones cripto mediante Chainalysis, integrado a Fireblocks.
Gestión de compliance
Gestión de alertas AML y casos de investigación mediante Sumsub.
Procesos operativos
Definición de procedimientos para:
revisión de alertas
análisis de riesgo
decisiones de bloqueo o revisión de clientes.
No incluye

El presente proyecto no contempla en esta fase:

desarrollo de un motor de riesgo propio (Risk Engine)
desarrollo de un sistema interno de gestión de casos AML
automatización completa de decisiones AML en tiempo real
integración directa entre todos los proveedores a nivel de orquestación central.

Estas capacidades se evaluarán en fases futuras de evolución de la arquitectura de compliance.

9. Roles y ownership
Business Owner (BO): Fiorella
Product Manager (PM): Mauricio Melo
Engineering (EM): Carlos Unda
Canal del proyecto: #tmp-proyecto-
10. Plan y timeline (H1 2026/27)

Tres frentes en paralelo:

O1:
O2:
O3:
O4:
O5:
11. Ceremonias y comunicación
Weekly Execution Sync (45 min – obligatorio)

Participantes: BO, PM, EM

Estructura fija:
Estado vs plan (verde / amarillo / rojo)
Bloqueos
Decisiones necesarias
Trade-offs
Próximo hito y responsables

Toda decisión debe documentarse en:

Canal del proyecto
Documento central