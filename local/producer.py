# generar_datos_prueba.py

import pandas as pd
from google.cloud import storage
from faker import Faker
import random
from datetime import datetime, timedelta
import pytz
from uuid import uuid4

# --- Configuración ---
# Reemplaza con tu GCP Project ID real y el nombre de tu bucket de landing.
GCP_PROJECT_ID = ""
LANDING_BUCKET_NAME = "self-crm-landing-zone-*****"

# Inicializa Faker para generar datos de prueba (en español)
fake = Faker('es_ES')

def generar_datos_cliente(num_filas=10000, source_file_name="clientes.csv"):
    """Genera un DataFrame de Pandas con datos de clientes de prueba completos."""

    tipos_de_plan = ["Prepago", "Plan 50GB", "Plan 100GB", "Plan Ilimitado"]
    estados_de_cuenta = ["Activo", "Activo", "Activo", "Suspendido por deuda", "Cancelado"]
    tipos_de_evento = ["actualizacion_consumo", "cambio_plan", "cambio_direccion", "actualizacion_estado"]
    marcas_dispositivo = ["Samsung", "Apple", "Xiaomi", "Motorola", "Huawei"]
    origenes_captacion = ["Tienda Fisica", "Venta Web", "Call Center", "Distribuidor Autorizado"]
    
    data = []
    for i in range(num_filas):
        # Genera una fecha y hora de evento aleatoria en el último día
        fecha_evento = fake.date_time_between(start_date='-1d', tzinfo=pytz.timezone('America/Lima'))
        
        # FIXED: Correct way to generate past dates with Faker
        fecha_registro = fake.date_between(start_date='-3y', end_date='today')
        
        # Calculate client age in months
        antiguedad_meses = (datetime.now().date() - fecha_registro).days // 30
        
        # Generate a realistic device ID (IMEI-like format)
        device_id = f"{random.randint(100000, 999999)}{random.randint(100000, 999999)}{random.randint(100, 999)}"
        
        fila = {
            "id_cliente": f"cust{1000 + i}",
            "numero_telefono": f"519{random.randint(10000000, 99999999)}",  # Fixed phone number generation
            "nombre_cliente": fake.name(),
            "direccion": fake.address().replace('\n', ', '),
            "tipo_plan": random.choice(tipos_de_plan),
            "consumo_datos_gb": round(random.uniform(0.5, 150.0), 2),
            "estado_cuenta": random.choice(estados_de_cuenta),
            "fecha_registro": fecha_registro.strftime('%Y-%m-%d'),
            "fecha_evento": fecha_evento.isoformat(),
            "tipo_evento": random.choice(tipos_de_evento),
            "id_dispositivo": device_id,  # FIXED: Custom device ID generation
            "marca_dispositivo": random.choice(marcas_dispositivo),
            "antiguedad_cliente_meses": antiguedad_meses,
            "score_crediticio": random.randint(300, 850),
            "origen_captacion": random.choice(origenes_captacion),
            "ingestion_ts": datetime.utcnow().isoformat(timespec="microseconds") + "Z",
            "event_uuid":    str(uuid4()),                     # idempotent merge key
            # helpful if you later want to trace each file
            "source_file":   source_file_name,                 # set below
        }
        data.append(fila)
    
    return pd.DataFrame(data)

def subir_a_gcs(bucket_name, source_file_name, destination_blob_name):
    """Sube un archivo al bucket de GCS especificado."""
    try:
        storage_client = storage.Client(project=GCP_PROJECT_ID)
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(destination_blob_name)

        blob.upload_from_filename(source_file_name)

        print(f"Archivo {source_file_name} subido a gs://{bucket_name}/{destination_blob_name}.")
        return True
    except Exception as e:
        print(f"Error al subir el archivo a GCS: {e}")
        return False

def main():
    """Función principal del script."""
    try:

        
        # Definir los nombres de archivo local y remoto
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        local_csv_filename = f"eventos_clientes_{timestamp}.csv"
        gcs_blob_name = local_csv_filename

        # Generar los datos
        print("Generando datos de prueba...")
        customer_df = generar_datos_cliente(num_filas=5000, source_file_name=local_csv_filename)
        
        # Guardar el DataFrame en un archivo CSV local
        customer_df.to_csv(local_csv_filename, index=False, encoding='utf-8')
        print(f"✅ Se generaron {len(customer_df)} filas de datos de prueba y se guardaron en {local_csv_filename}.")
        
        # Mostrar una muestra de los datos
        print("\n📊 Muestra de los datos generados:")
        print(customer_df.head())
        
        # Subir el archivo a GCS
        print(f"\n📤 Subiendo archivo a GCS bucket: {LANDING_BUCKET_NAME}...")
        success = subir_a_gcs(
            bucket_name=LANDING_BUCKET_NAME,
            source_file_name=local_csv_filename,
            destination_blob_name=gcs_blob_name,
        )
        
        if success:
            print("✅ ¡Archivo subido exitosamente! El pipeline de datos debería activarse automáticamente.")
        else:
            print("❌ Error al subir el archivo.")
            
    except Exception as e:
        print(f"❌ Error en la ejecución del script: {e}")
        raise

if __name__ == "__main__":
    main()