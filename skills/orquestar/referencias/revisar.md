# Revisar un diff

Lee el diff real (`git -C <worktree> diff <rama-principal>...HEAD`), no el resumen del agente: el
resumen describe la intención, el diff es lo que va a producción. Aplica **cada** punto; uno que no
aplica se descarta explícitamente, no se salta.

## Contra la spec
- Hace lo que pide el issue, en los archivos que le tocaban. Todo lo que tocó fuera tiene una razón.
- Las "desviaciones" que el agente reporta son aceptables o se devuelven. Una desviación no reportada
  que encuentres pesa más que una reportada.
- Los TODO que deja apuntan a un issue existente.

## Correctitud que los tests no ven
- **Confianza:** valores que llegan del cliente (formularios, query, body, cookies) se recalculan o
  validan en el servidor: montos, IDs de otra organización/usuario, roles.
- **Aislamiento:** toda consulta filtra por el dueño (organización, usuario, repartidor…). Acceso con
  credenciales de administrador → filtro explícito en cada consulta.
- **Privacidad:** datos personales solo mientras se necesitan; cachés del navegador/teléfono se limpian
  al terminar; nada sensible en logs.
- **Secretos y aleatoriedad:** secretos nunca en claro en base ni en logs; códigos/tokens con fuente
  criptográfica, no `Math.random`.
- **Idempotencia:** reintentos de red, colas y sincronizaciones no aplican dos veces el mismo efecto.
- **Efectos colaterales en cadena:** si un evento dispara avisos, cobros o notificaciones, un estado
  intermedio "falso" (p. ej. marcar entregado para luego revertir) dispara el efecto de verdad.
- **Guardas y filtros:** busca los falsos positivos, no solo los negativos (un filtro que bloquea
  respuestas válidas es un bug).
- **Estados y transiciones:** transiciones inválidas lanzan; hay camino para los casos de negocio
  (reasignar, cancelar, reintentar).

## Integración con el resto
- **Duplicados:** el agente no reinventó una función que ya existe (búscala por nombre y por
  comportamiento). Dos piezas paralelas no crearon la misma función con firmas distintas.
- **Contratos entre piezas:** rutas, nombres de eventos, payloads y env vars coinciden entre quien
  produce y quien consume (p. ej. el enlace de un push apunta a una ruta que existe).
- **Todos los caminos que mutan** pasan por el mismo servicio (no hay una acción del panel que cambie
  estado saltándose los efectos que sí aplica la API).

## Cosas que el agente inventa o rompe sin querer
- **Versiones, etiquetas de imagen, nombres de paquetes, URLs:** verifica que existan
  (`docker manifest inspect`, el registro de paquetes, `--help`).
- **Codificación:** archivos generados desde PowerShell pueden llevar BOM (rompe SQL y algunos parsers):
  `head -c 3 <archivo> | od -c`.
- **Lockfile** actualizado si agregó dependencias; migraciones generadas, no escritas a mano; ninguna
  migración destructiva no pedida.
- **Tests debilitados:** un test cambiado para pasar (expectativa ajustada, caso borrado) en vez de
  arreglar el código.
- **Idioma y tono** del texto al usuario final según la convención del proyecto.

## Verificación
Corre tú, en el worktree o tras fusionar en la rama principal, las verificaciones del proyecto (tipos,
lint, tests y compilación si hay dependencias o assets nuevos). Una por una y leyendo el **código de
salida del comando**, no el de un `| tail`. Errores preexistentes que aparezcan también se arreglan.

## Devolver
Cada hallazgo como: problema concreto → resultado esperado → por qué importa (la consecuencia real).
Todo en un archivo de revisión (`plantillas.md`) y al mismo agente, en el mismo worktree.
