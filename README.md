# Repositorio de Cloud Functions - Plataforma de Datos

Este repositorio contiene el código fuente (Python) y la infraestructura como código (Terraform) para desplegar funciones serverless en la plataforma de datos.

Este proyecto utiliza un único conjunto de archivos de Terraform para empaquetar y desplegar una función específica. El despliegue se activa automáticamente cuando se detectan cambios en el código fuente de la función a través de un **hash de contenido**, asegurando que solo se realicen actualizaciones cuando sea necesario.

## Arquitectura y Filosofía

La gestión de la infraestructura está dividida en dos repositorios para seguir el principio de separación de responsabilidades:

1.  **Repositorio de Plataforma (`self-data-platform`):**
    * Gestiona la infraestructura base y compartida (VPC, buckets, cuentas de servicio para CI/CD, etc.).
    * Define las "identidades" (cuentas de servicio) que las aplicaciones pueden usar.
    * Es gestionado por el equipo de plataforma.

2.  **Este Repositorio (`self-data-platform-functions`):**
    * Contiene la lógica de negocio de la función (código Python).
    * Contiene la infraestructura específica para desplegar esa función.
    * Utiliza el estado remoto del repositorio de plataforma para acceder a recursos compartidos (como el nombre de los buckets).
    * Es gestionado por los equipos de desarrollo de datos.

## Prerrequisitos

Para trabajar con este repositorio, necesitarás tener instalado lo siguiente:

* [Terraform](https://developer.hashorp.com/terraform/downloads) (v1.5.0 o superior)
* [Google Cloud SDK (gcloud)](https://cloud.google.com/sdk/docs/install)
* Python 3.9+

## Estructura del Repositorio

El repositorio está organizado con los archivos de Terraform en la raíz y el código fuente de la función en un subdirectorio `src`.

```
.
├── .github/
│   └── workflows/
│       └── deploy.yml      # Workflow de CI/CD para despliegue
│
├── src/
│   └── load_landing_to_raw/
│       ├── main.py         # Código fuente de la función
│       └── requirements.txt# Dependencias de Python
│
├── backend.tf
├── data.tf
├── iam.tf
├── main.tf
├── variables.tf
└── ... (otros archivos .tf en la raíz)
```

## Proceso de Despliegue (Basado en Hash)

El despliegue está diseñado para ser eficiente y solo se activa cuando el código fuente de la función cambia.

1.  **Cambios en el Código:** Un desarrollador modifica el código en `src/load_landing_to_raw/main.py`.
2.  **Generación del Hash:** Durante la ejecución de Terraform (`plan` o `apply`), el `data "archive_file"` empaqueta el directorio `src/load_landing_to_raw` en un archivo `.zip` y calcula un hash único (SHA256) basado en el contenido de los archivos.
3.  **Detección de Cambios:**
    * El recurso `google_storage_bucket_object` nombra el archivo `.zip` subido a GCS usando este hash (ej. `source-HASH123.zip`).
    * Si el código cambia, el hash cambia, y por lo tanto, el nombre del archivo en GCS cambia.
    * El recurso `google_cloudfunctions2_function` detecta que su `source.storage_source.object` ha cambiado (de `source-HASH123.zip` a `source-HASH456.zip`) y planifica una actualización.
4.  **Despliegue:** Si se detecta un cambio en el hash, Terraform actualiza la Cloud Function para que utilice el nuevo paquete de código. Si no hay cambios en el código, el hash no cambia y Terraform no realiza ninguna acción sobre la función.

---

## Configuración para Desarrollo Local

Antes de poder ejecutar `terraform apply` desde tu máquina local, necesitas realizar una configuración inicial única.

### 1. Crear el Bucket para el Backend de Terraform

Terraform necesita un bucket en GCS para almacenar su archivo de estado de forma segura. Este bucket debe ser creado manualmente una sola vez.

```bash
# Reemplaza 'tu-gcp-project-id-aqui' con tu Project ID
gcloud storage buckets create gs://self-tfstate-bkt --project=tu-gcp-project-id-aqui --location=us-central1 --uniform-bucket-level-access
```

### 2. Permisos de Usuario Local

Tu cuenta de usuario de Google Cloud (con la que te autenticas a través de `gcloud`) necesita tener los permisos necesarios para crear los recursos definidos en este proyecto. Para un entorno de desarrollo, los siguientes roles son recomendados:

* **Project IAM Admin** (`roles/resourcemanager.projectIamAdmin`): Para gestionar los permisos de las cuentas de servicio.
* **Service Account Admin** (`roles/iam.serviceAccountAdmin`): Para crear y gestionar cuentas de servicio.
* **Storage Admin** (`roles/storage.admin`): Para crear buckets y gestionar permisos.
* **Cloud Functions Developer** (`roles/cloudfunctions.developer`): Para desplegar Cloud Functions.
* **Eventarc Admin** (`roles/eventarc.admin`): Para crear los triggers de eventos.

Puedes asignarte estos roles desde la consola de GCP en la sección de IAM.

### 3. Archivo de Variables Locales (`terraform.tfvars`)

Crea un archivo llamado `terraform.tfvars` en la raíz de este repositorio y añade las variables necesarias. Terraform cargará este archivo automáticamente.

```terraform
# terraform.tfvars

gcp_project_id      = "tu-gcp-project-id-aqui"
gcp_region          = "us-central1"
function_source_dir = "src/load_landing_to_raw"

```

---

### Despliegue Manual (Para Desarrollo y Pruebas)

Una vez completada la configuración local, puedes desplegar la función manualmente:

1.  **Autenticación:** Asegúrate de estar autenticado en Google Cloud.
    ```bash
    gcloud auth application-default login
    ```

2.  **Navega al Directorio Raíz:** Sitúate en la raíz de este repositorio.

3.  **Inicializa Terraform:** Configura el backend y los proveedores.
    ```bash
    terraform init
    ```

4.  **Planifica y Aplica:** Revisa los cambios y aplícalos.
    ```bash
    terraform plan
    terraform apply
    ```

## Configuración de la Función

La función que se despliega se controla a través de la variable `function_source_dir` en el archivo `variables.tf` (o en tu `terraform.tfvars` local). Para desplegar una función diferente, deberás actualizar esta variable para que apunte al directorio de código fuente correcto dentro de `src/`.
