/* AUTOGENERADO por backend/scripts/generar-derivados.ts desde datos-espaciales/*.geojson. No editar a mano.
 * Si fuenteDatos === 'demostracion' los trazados y paradas son ILUSTRATIVOS, no oficiales. */
import type { Parada, Ruta } from './types';

export interface RutaLocal {
  ruta: Ruta;
  paradas: Parada[];
}

export const RUTAS_LOCALES: RutaLocal[] = [
  {
    "ruta": {
      "idRuta": 1,
      "numeroRuta": "38",
      "nombre": "Ruta 38 (demostración)",
      "origen": "Parque Hidalgo / Centro Histórico",
      "destino": "Terminal ruta 38 (demostración)",
      "distanciaKm": null,
      "colorHex": "#1687ff",
      "horarioInicio": "06:00",
      "horarioFin": "21:00",
      "frecuenciaPromedioMin": null,
      "activa": true,
      "trazado": [
        {
          "latitud": 20.3889,
          "longitud": -99.9961
        },
        {
          "latitud": 20.3885,
          "longitud": -99.993
        },
        {
          "latitud": 20.3872,
          "longitud": -99.9895
        },
        {
          "latitud": 20.386,
          "longitud": -99.986
        },
        {
          "latitud": 20.3851,
          "longitud": -99.982
        },
        {
          "latitud": 20.384,
          "longitud": -99.9775
        },
        {
          "latitud": 20.3826,
          "longitud": -99.9735
        },
        {
          "latitud": 20.381,
          "longitud": -99.97
        },
        {
          "latitud": 20.3805,
          "longitud": -99.966
        },
        {
          "latitud": 20.3815,
          "longitud": -99.962
        },
        {
          "latitud": 20.383,
          "longitud": -99.9585
        }
      ],
      "fuenteDatos": "demostracion"
    },
    "paradas": [
      {
        "idParada": 1,
        "idRuta": 1,
        "nombre": "Parque Hidalgo / Centro Histórico",
        "referenciaVial": "Calle Miguel Hidalgo (referencia vial según Avance 1)",
        "ordenSecuencia": 1,
        "esNodoTransferencia": true,
        "latitud": 20.3889,
        "longitud": -99.9961
      },
      {
        "idParada": 2,
        "idRuta": 1,
        "nombre": "Av. Universidad (demostración)",
        "referenciaVial": "Av. Universidad",
        "ordenSecuencia": 2,
        "esNodoTransferencia": false,
        "latitud": 20.386,
        "longitud": -99.986
      },
      {
        "idParada": 3,
        "idRuta": 1,
        "nombre": "Río Moctezuma / Claveles",
        "referenciaVial": "Zona Río Moctezuma / Claveles",
        "ordenSecuencia": 3,
        "esNodoTransferencia": false,
        "latitud": 20.384,
        "longitud": -99.9775
      },
      {
        "idParada": 4,
        "idRuta": 1,
        "nombre": "Instituto Tecnológico (ITSJR)",
        "referenciaVial": "Av. Tecnológico",
        "ordenSecuencia": 4,
        "esNodoTransferencia": true,
        "latitud": 20.3805,
        "longitud": -99.966
      },
      {
        "idParada": 5,
        "idRuta": 1,
        "nombre": "Terminal ruta 38 (demostración)",
        "referenciaVial": "Punto final ilustrativo",
        "ordenSecuencia": 5,
        "esNodoTransferencia": false,
        "latitud": 20.383,
        "longitud": -99.9585
      }
    ]
  },
  {
    "ruta": {
      "idRuta": 2,
      "numeroRuta": "39",
      "nombre": "Ruta 39 (demostración)",
      "origen": "Base ruta 39 (demostración)",
      "destino": "Terminal ruta 39 (demostración)",
      "distanciaKm": null,
      "colorHex": "#ed69b5",
      "horarioInicio": "06:00",
      "horarioFin": "21:00",
      "frecuenciaPromedioMin": null,
      "activa": true,
      "trazado": [
        {
          "latitud": 20.379,
          "longitud": -100.004
        },
        {
          "latitud": 20.38,
          "longitud": -100
        },
        {
          "latitud": 20.3812,
          "longitud": -99.996
        },
        {
          "latitud": 20.3815,
          "longitud": -99.992
        },
        {
          "latitud": 20.3808,
          "longitud": -99.988
        },
        {
          "latitud": 20.38,
          "longitud": -99.984
        },
        {
          "latitud": 20.3805,
          "longitud": -99.98
        },
        {
          "latitud": 20.3812,
          "longitud": -99.976
        }
      ],
      "fuenteDatos": "demostracion"
    },
    "paradas": [
      {
        "idParada": 6,
        "idRuta": 2,
        "nombre": "Base ruta 39 (demostración)",
        "referenciaVial": "Punto inicial ilustrativo",
        "ordenSecuencia": 1,
        "esNodoTransferencia": false,
        "latitud": 20.379,
        "longitud": -100.004
      },
      {
        "idParada": 7,
        "idRuta": 2,
        "nombre": "Hda. Los Arrayanes (demostración)",
        "referenciaVial": "Hda. Los Arrayanes",
        "ordenSecuencia": 2,
        "esNodoTransferencia": false,
        "latitud": 20.3812,
        "longitud": -99.996
      },
      {
        "idParada": 8,
        "idRuta": 2,
        "nombre": "Av. Tecnológico (demostración)",
        "referenciaVial": "Av. Tecnológico",
        "ordenSecuencia": 3,
        "esNodoTransferencia": false,
        "latitud": 20.3808,
        "longitud": -99.988
      },
      {
        "idParada": 9,
        "idRuta": 2,
        "nombre": "Instituto Tecnológico (ITSJR)",
        "referenciaVial": "Av. Tecnológico",
        "ordenSecuencia": 4,
        "esNodoTransferencia": true,
        "latitud": 20.3805,
        "longitud": -99.98
      },
      {
        "idParada": 10,
        "idRuta": 2,
        "nombre": "Terminal ruta 39 (demostración)",
        "referenciaVial": "Punto final ilustrativo",
        "ordenSecuencia": 5,
        "esNodoTransferencia": false,
        "latitud": 20.3812,
        "longitud": -99.976
      }
    ]
  }
];
