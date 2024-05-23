
# Despliegue de Red Hyperledger Fabric para Sistema de Ticketing

Este repositorio alberga un proyecto destinado a implementar un caso de uso de una red privada de Hyperledger Fabric (HLF) basada en la [versión 2.5.7](https://github.com/hyperledger/fabric/releases/tag/v2.5.7). Se puede encontrar la documentación oficial de Hyperledger Fabric [aquí](https://hyperledger-fabric.readthedocs.io/en/release-2.5/).

## Visión General de la Red HLF

### Participantes

La red HLF está compuesta por:

* Un Nodo Orderer
* Tres peers de organizaciones:
    - Organización Cliente con un nodo peer (peer0.orgclient)
    - Organización Developer con un nodo peer (peer0.orgdev)
    - Organización QA con un nodo peer (peer0.orgqa)

### Caso de Uso

La red HLF simula un sistema de gestión de tickets para proyectos de software:

* Organización Cliente abre tickets para resolver incidencias o implementar funcionalidades.
* Organización Developer asume y resuelve estos tickets.
* Organización QA realiza pruebas y asegura la calidad de los tickets resueltos.

### Canales

Se crean dos canales con la siguiente distribución organizacional:

* channeldev: Organización Cliente y Organización Developer
* channelqa: Organización Cliente y Organización QA

### Chaincode

Un Chaincode llamado 'ticketingSystemContract' se instala en los tres peers. 
Una vez levantada la red e instalado y desplegado el Chaincode, se generan transacciones que simulan la lógica del sistema de gestión de tickets.

## Prerrequisitos

Existen una serie de scripts en bash disponibles en la ruta 'network/scripts/'

Se puede ejecutar el script 'installPrerequisites.sh' para instalar los paquetes necesarios:

```bash
./installPrerequisites.sh
```
La lista de paquetes que se instala es la siguiente:

* curl
* docker.io
* docker-compose
* golang
* jq
* openjdk-11-jdk

```bash
sudo apt install git curl docker.io docker-compose golang jq openjdk-11-jdk -y
```

El script también realiza configuraciones adicionales relacionadas con el servicio Docker.

## Scripts

### Crear y Desplegar la Red HLF

Usar el script 'networkAll.sh' para crear y desplegar la red HLF. Este script realiza los siguientes pasos:

* Borrar instancias anteriores de la red: 'networkDelete.sh'
* Crear la red, generar los artefactos necesarios y arrancar todos los servicios o contenedores, incluyendo los nodos Orderer y peers: 'networkUp.sh'
* Crear los canales y unir los peers a ellos: 'networkCreateChannels.sh'
* Compilar el código fuente del Chaincode, empaquetarlo, instalarlo en todos los peers y comprometerlo en los canales: 'networkDeployCC.sh'

Por el momento, solo el Chaincode 'ticketingSystemContract' está disponible, pero otros Chaincodes futuros se pueden desplegar usando:

```bash
./networkDeployCC.sh <nombre_chaincode> <version>
```

Ejemplo:

```bash
./networkDeployCC.sh "ticketingSystemContract" "1.0"
```

### Interactuar con el Chaincode

Usar el script 'interactWithCC.sh' para realizar acciones sobre la red en relación con el Chaincode, generando transacciones de ejemplo. El uso del script es:

```bash
./interactWithCC.sh <canal> <org>
```

Ejemplos:

```bash
./interactWithCC.sh channeldev client
./interactWithCC.sh channeldev developer
```

La organizacion '<org>' que se especifica en el comando es la identidad del peer desde la que se realizaran las consultas y/o llamadas a las funciones definidas en el Chaincode.

### Finalizar o desactivar la Red HLF

Ejecutar el script 'networkStop.sh' para detener los contenedores y servicios en ejecución. Esta acción no borra datos ni configuraciones de la red HLF.

```bash
./networkStop.sh
```
NOTA: Se puede levantar la red de nuevo mediante el script 'networkUp.sh' sin necesidad de crear y configurar desde cero todo el proceso.

### Monitorizar la Red HLF

Lanzar el script 'monitordocker.sh' para iniciar un contenedor Docker llamado "logspout" que monitorea los logs de todos los contenedores de la red desplegada.

```bash
./monitordocker.sh
```

También maneja la finalización segura del contenedor cuando se interrumpe el script.
