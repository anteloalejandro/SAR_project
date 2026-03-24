#set text(font: "Ubuntu")
#set document(
  title: "Buscador Web",
  author: "Alejandro Antelo Fashoro"
)

#title()

= Miembros del grupo

Alejandro Antelo Fashoro

= Implementaciones

== Indexación

=== Función ```python index_file()```

Se llama a esta función desde ```python index_dir()```, que itera por todos los `json` del directorio especificado como "raíz" llamando a esta función.

En los _datasets_, los archivos `json` no siguen correctamente el formato JSON, sino que cada línea de los archivos constituye un objeto JSON.

Lo siguiente es un ejemplo de un objeto JSON, formateado, en una de las líneas de los _datasets_:

```json
{
  "url": "https://es.wikipedia.org/wiki/Ronald_Melzer",
  "title": "Ronald Melzer",
  "summary": " \n \n \n \n \n \n \n \nRonald «Ronny» Melzer (Montevideo, 17 de diciembre de 1956 - Montevideo, 24 de junio de 2013) fue un crítico y productor de cine, periodista deportivo, árbitro de fútbol y contador público uruguayo.[1]​",
  "sections": [
    {
      "name": "Biografía",
      "text": "Nació en Montevideo en una familia de inmigrantes judíos. Fue contador público pero nunca ejerció la profesión, empleado bancario y árbitro de fútbol de la AUF.[2]​ A partir de 1979 se dedicó a la crítica cinematográfica y trabajó en varias publicaciones. Fue el encargado de editar la sección uruguaya de la Enciclopedia del Cine Iberoamericano de la Sociedad General de Autores y Editores (SGAE).[3]​\nLa mayor parte de su trayectoria como crítico de cine la desarrolló en el semanario Brecha, donde también escribía sobre fútbol con el seudónimo de «Harry Hinkle»,[4]​ en referencia cinéfila al camarógrafo deportivo interpretado por Jack Lemmon en la película En bandeja de plata (The Fortune Cookie), de Billy Wilder.[5]​\nFundó y dirigió durante 28 años, hasta su fallecimiento, «Video Imagen Club», influyente videoclub especializado en cine clásico, que se convirtió en motor de una generación de cineastas uruguayos que incluye a los directores de cine Juan Pablo Rebella y Pablo Stoll y al actor Daniel Hendler, entre otros.[6]​[7]​ Con la misma orientación también fundó la editora en VHS «Videograma», que luego se transformó en la distribuidora y productora de cine «BuenCine Producciones».[6]​[8]​ Fue productor asociado de las películas 25 watts (2001), Gigante (2008), El círculo (2009) y Rambleras (2010), entre otras producciones.[3]​\nInterpretó el papel de un juez de línea en la película Whisky (2004), dirigida por Juan Pablo Rebella y Pablo Stoll.\nProdujo la serie de televisión El Cine de los Uruguayos, de Televisión Nacional Uruguay, con dirección de Guillermo Casanova.[3]​ A la fecha de su fallecimiento tenía varios proyectos en preproducción.[9]​\nFalleció en 2013. Sus restos yacen en el Cementerio Israelita de La Paz.[1]​",
      "subsections": []
    },
    {
      "name": "Referencias",
      "text": "↑ a b El hombre que miraba diferente\n↑ «Ronald Melzer: Múltiples maneras de amar el cine». Asociación de Críticos de Cine del Uruguay (ACCU). Consultado el 15 de julio de 2013. \n↑ a b c «Ronald Melzer (1956 - 2013)». Ministerio de Educación y Cultura de Uruguay. Consultado el 15 de julio de 2013. \n↑ «Harry Hinkle, columnista deportivo». Brecha. 28 de junio de 2013. Archivado desde el original el 5 de julio de 2013. Consultado el 15 de julio de 2013. \n↑ «The Fortune Cookie (1966)» (en inglés). Turner Classic Movies. Consultado el 15 de julio de 2013. \n↑ a b «El guardián del cine uruguayo». El Observador. 16 de marzo de 2013. Archivado desde el original el 21 de julio de 2013. Consultado el 15 de julio de 2013. \n↑ «El guardián del cine dijo adiós». El Observador. 24 de junio de 2013. Archivado desde el original el 29 de junio de 2013. Consultado el 15 de julio de 2013. \n↑ «Murió Ronald Melzer». El Observador. 24 de junio de 2013. Archivado desde el original el 30 de julio de 2013. Consultado el 15 de julio de 2013. \n↑ «Falleció Ronald Melzer, el custodio del cine uruguayo». Radio El Espectador. 24 de junio de 2013. Consultado el 15 de julio de 2013. ",
      "subsections": []
    },
    {
      "name": "Enlaces externos",
      "text": "Único, insoportable, irremplazable. Ronald Melzer (1956-2013) (enlace roto disponible en Internet Archive; véase el historial, la primera versión y la última)., Obituario por Rosalba Oxandabarat en Brecha, 12 de julio de 2013.\nPlaceres culposos. Sobre Una pistola en cada mano, de Cesc Gay. Última crítica de Ronald Melzer (enlace roto disponible en Internet Archive; véase el historial, la primera versión y la última)., Brecha, 23 de mayo de 2013.\nEntrevista a Ronald Melzer, Guía 50, marzo de 2013.\nRonald Melzer en Internet Movie Database (en inglés).",
      "subsections": []
    }
  ]
}
```

Nótese que el texto contiene caracteres UNICODE especiales como el _Zero-Width Space_.

La función ```python parse_article()``` es la que se encarga de extraer el texto de los objetos JSON de cada archivo. Esta función devuelve un diccionario ```python Dict[str, str]``` contiene:
- `url`
- `title`
- `summary`
- `all`: contiene todo el texto del título, resumen y secciones, separado por saltos de línea.
- `section-name`: Contiene los nombres de las secciones, separados por saltos de línea.

Después se limpia esta única cadena de texto eliminando todos los caracteres no alfanuméricos, exceptuando los delimitadores de términos (espacio, salto de línea y tabulador). Para ello extrae todo lo que encaja con la expresión regular ```re /[\w\s]+/``` y se aúna en una nueva cadena.

Tras limpiar la cadena, se pasa a minúscula, y se separa en términos en base a los delimitadores ```re \s+```, obviando los términos vacíos.

Cada artículo debe tener un identificador único que sea único entre el resto de artículos de todos los archivos y permita identificar a qué documento (archivo `.json`) pertenece.

Cada documento, a su vez, tiene un identificador entero secuencial `docid`, a partir del cual se calcula el identificador de artículo

== Similitud semántica

=== Función ```python update_chunks()```

Haciendo uso de la librería `nltk`, se cargan los chunks de `frases.txt`.

= Ampliaciones

== Título de ampliación aquí
