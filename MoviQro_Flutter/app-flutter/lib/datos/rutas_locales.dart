// AUTOGENERADO por backend/scripts/generar-derivados.ts desde datos-espaciales/*.geojson. No editar a mano.
// Si fuenteDatos == demostracion, los trazados y paradas son ILUSTRATIVOS, no oficiales.
import '../core/tipos.dart';

final List<RutaConParadas> rutasLocales = [
  RutaConParadas(
    ruta: Ruta(
      idRuta: 1, numeroRuta: "38", nombre: "Ruta 38 (demostración)",
      origen: "Parque Hidalgo / Centro Histórico", destino: "Terminal ruta 38 (demostración)", distanciaKm: null, colorHex: "#1687ff",
      horarioInicio: "06:00", horarioFin: "21:00", frecuenciaPromedioMin: null,
      activa: true, fuenteDatos: FuenteDatos.demostracion,
      trazado: [
      Coordenada(20.3889, -99.9961),
      Coordenada(20.3885, -99.993),
      Coordenada(20.3872, -99.9895),
      Coordenada(20.386, -99.986),
      Coordenada(20.3851, -99.982),
      Coordenada(20.384, -99.9775),
      Coordenada(20.3826, -99.9735),
      Coordenada(20.381, -99.97),
      Coordenada(20.3805, -99.966),
      Coordenada(20.3815, -99.962),
      Coordenada(20.383, -99.9585),
      ],
    ),
    paradas: [
      Parada(idParada: 1, idRuta: 1, nombre: "Parque Hidalgo / Centro Histórico", referenciaVial: "Calle Miguel Hidalgo (referencia vial según Avance 1)", ordenSecuencia: 1, esNodoTransferencia: true, latitud: 20.3889, longitud: -99.9961),
      Parada(idParada: 2, idRuta: 1, nombre: "Av. Universidad (demostración)", referenciaVial: "Av. Universidad", ordenSecuencia: 2, esNodoTransferencia: false, latitud: 20.386, longitud: -99.986),
      Parada(idParada: 3, idRuta: 1, nombre: "Río Moctezuma / Claveles", referenciaVial: "Zona Río Moctezuma / Claveles", ordenSecuencia: 3, esNodoTransferencia: false, latitud: 20.384, longitud: -99.9775),
      Parada(idParada: 4, idRuta: 1, nombre: "Instituto Tecnológico (ITSJR)", referenciaVial: "Av. Tecnológico", ordenSecuencia: 4, esNodoTransferencia: true, latitud: 20.3805, longitud: -99.966),
      Parada(idParada: 5, idRuta: 1, nombre: "Terminal ruta 38 (demostración)", referenciaVial: "Punto final ilustrativo", ordenSecuencia: 5, esNodoTransferencia: false, latitud: 20.383, longitud: -99.9585),
    ],
  ),
  RutaConParadas(
    ruta: Ruta(
      idRuta: 2, numeroRuta: "39", nombre: "Ruta 39 (demostración)",
      origen: "Base ruta 39 (demostración)", destino: "Terminal ruta 39 (demostración)", distanciaKm: null, colorHex: "#ed69b5",
      horarioInicio: "06:00", horarioFin: "21:00", frecuenciaPromedioMin: null,
      activa: true, fuenteDatos: FuenteDatos.demostracion,
      trazado: [
      Coordenada(20.379, -100.004),
      Coordenada(20.38, -100.0),
      Coordenada(20.3812, -99.996),
      Coordenada(20.3815, -99.992),
      Coordenada(20.3808, -99.988),
      Coordenada(20.38, -99.984),
      Coordenada(20.3805, -99.98),
      Coordenada(20.3812, -99.976),
      ],
    ),
    paradas: [
      Parada(idParada: 6, idRuta: 2, nombre: "Base ruta 39 (demostración)", referenciaVial: "Punto inicial ilustrativo", ordenSecuencia: 1, esNodoTransferencia: false, latitud: 20.379, longitud: -100.004),
      Parada(idParada: 7, idRuta: 2, nombre: "Hda. Los Arrayanes (demostración)", referenciaVial: "Hda. Los Arrayanes", ordenSecuencia: 2, esNodoTransferencia: false, latitud: 20.3812, longitud: -99.996),
      Parada(idParada: 8, idRuta: 2, nombre: "Av. Tecnológico (demostración)", referenciaVial: "Av. Tecnológico", ordenSecuencia: 3, esNodoTransferencia: false, latitud: 20.3808, longitud: -99.988),
      Parada(idParada: 9, idRuta: 2, nombre: "Instituto Tecnológico (ITSJR)", referenciaVial: "Av. Tecnológico", ordenSecuencia: 4, esNodoTransferencia: true, latitud: 20.3805, longitud: -99.98),
      Parada(idParada: 10, idRuta: 2, nombre: "Terminal ruta 39 (demostración)", referenciaVial: "Punto final ilustrativo", ordenSecuencia: 5, esNodoTransferencia: false, latitud: 20.3812, longitud: -99.976),
    ],
  ),
];
