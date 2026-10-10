# Preparación cloud pendiente — TP1

La evidencia realizada es el despliegue local con Docker Compose. No se ha
creado un proyecto ni se han contratado recursos. Los siguientes nombres son
propuestos, no recursos existentes:

| Recurso | Nombre propuesto |
|---|---|
| Proyecto | coldtrace-tp1-g13 (sujeto a disponibilidad global) |
| Región | us-central1 |
| Artifact Registry | coldtrace-services |
| Cloud Run | coldtrace-monitoring, coldtrace-alert, coldtrace-gateway |
| Pub/Sub | coldtrace.threshold.breached, coldtrace.source.gap |
| Cloud SQL, si se autoriza | coldtrace-mysql-tp1 |

Cloud Run y Pub/Sub tienen cuotas gratuitas, pero no garantizan una factura
cero. Cloud SQL no ofrece una instancia MySQL permanentemente gratuita.
Por ahora el presupuesto de recursos contratados es cero; se ejecuta MySQL
local con esquemas y usuarios separados. No se debe presentar esta instalación
local como Cloud SQL. Ver precios y cuotas vigentes antes de crear recursos:
[Cloud Run](https://cloud.google.com/run/pricing),
[free tier](https://cloud.google.com/free/docs/free-cloud-features),
[Cloud SQL](https://cloud.google.com/sql/pricing).

Un despliegue cloud funcional requiere antes un publicador autenticado de
Pub/Sub, validación OIDC del receptor push, secretos reales, usuarios/dispositivos
reales y conectividad a MySQL. El receptor actual está habilitado explícitamente
solo para el emulador local. La ingesta no necesita IAM sincrónico; las consultas
de usuarios sí necesitan el IAM del sistema base.

Para una demostración breve se puede evaluar Cloud Run con mínimo cero, pero
los timers de detección de brechas y outbox no constituyen disponibilidad
continua si el proceso escala a cero o no recibe CPU fuera de las solicitudes.
Cumplir QA01 continuamente exige diseñar y presupuestar su ejecución, por ejemplo
instancias con CPU fuera de solicitudes o mecanismos de ejecución externos.
No se atribuye redundancia a una sola instancia.

La captura cloud y el despliegue integral 5.4 quedan pendientes. El incremento
TP1 puede demostrarse ahora mediante su despliegue local verificable.
