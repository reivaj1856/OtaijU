OtaijU






Fecha del Proyecto: 26 de Octubre de 2023

OtaijU es una aplicación móvil multiplataforma desarrollada con Flutter y Firebase, diseñada para que los usuarios puedan conectarse, compartir publicaciones, unirse a grupos y chatear en tiempo real.

📸 Capturas de Pantalla


Pantalla de inicio de sesión y registro


Visualización de publicaciones en el feed


Interacción mediante chat con otros usuarios

🔹 Tabla de Contenidos

Descripción

Arquitectura

Funcionalidades

Tecnologías Utilizadas

Instalación

Uso

Áreas de Mejora

Conclusiones

📝 Descripción

OtaijU permite a los usuarios:

Conectarse con otros usuarios mediante seguimiento mutuo.

Publicar contenido multimedia (texto, imágenes, videos).

Crear y unirse a grupos temáticos.

Chatear en tiempo real con otros usuarios.

La aplicación combina una interfaz atractiva y responsiva con funcionalidades modernas de redes sociales.

🏗 Arquitectura

Frontend: Flutter con enfoque en widgets y UI responsiva.
Backend: Firebase, incluyendo:

Firebase Authentication: Gestión de usuarios.

Cloud Firestore: Almacenamiento de usuarios, publicaciones, grupos y mensajes.

Firebase Storage (previsto): Almacenamiento de imágenes y videos.

Gestión de Estado: Provider para manejar datos y comunicación entre widgets.

⚡ Funcionalidades Principales

Autenticación: Registro e inicio de sesión con correo electrónico.

Perfil de Usuario: Visualización de información, seguidores y seguidos.

Publicaciones: Crear, ver, comentar y dar like a publicaciones.

Grupos: Crear, unirse y visualizar publicaciones dentro de grupos.

Mensajería: Chat en tiempo real y búsqueda de usuarios.

Seguimiento: Seguir y dejar de seguir usuarios, creación automática de conversaciones mutuas.

💻 Tecnologías Utilizadas

Flutter: Desarrollo multiplataforma.

Dart: Lenguaje de programación.

Firebase: Backend completo (Auth, Firestore, Storage).

Provider: Gestión de estado.

Image Picker: Selección de imágenes.

Youtube Player Flutter: Reproducción de videos.

⚙ Instalación

Clonar el repositorio:

git clone https://github.com/tu_usuario/otaiju.git


Abrir el proyecto en Android Studio o VS Code.

Sincronizar dependencias de Gradle o pub.

Configurar google-services.json con tu proyecto de Firebase.

Ejecutar en emulador o dispositivo físico:

flutter run

🚀 Uso

Registro/Iniciar Sesión: Ingresa con correo electrónico y contraseña.

Publicaciones: Crear publicaciones desde el feed o grupos.

Chat: Buscar usuarios y enviar mensajes en tiempo real.

Grupos: Crear y unirse a grupos para interactuar con miembros.

🔧 Áreas de Mejora

UI: Implementar temas claros y oscuros, mejorar diseño visual.

Funcionalidad: Editar perfil, subir imágenes/videos, notificaciones push.

Rendimiento: Optimizar carga de datos y listas grandes, usar caché y paginación.

Seguridad: Reglas más estrictas en Firestore y validación de entradas.

Pruebas: Implementar pruebas unitarias e integradas.

✅ Conclusiones

OtaijU es un proyecto prometedor y escalable. Con la implementación de las mejoras propuestas, puede consolidarse como una plataforma de redes sociales completa y atractiva para usuarios.
