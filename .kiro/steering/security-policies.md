---
inclusion: always
---

# Normas de seguridad del proyecto

- Nunca hardcodear contraseñas, tokens ni claves de API en el código.
  Todo secreto va en `.env`, que está en `.gitignore`.
- Validar y sanitizar todo input que venga del usuario antes de
  usarlo en una consulta SQL (usar parámetros, nunca concatenar strings).
- Las contraseñas de usuarios se guardan siempre hasheadas (bcrypt/argon2),
  nunca en texto plano.
- No exponer mensajes de error de la base de datos directamente al cliente.
