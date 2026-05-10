# versión 1.2

import json
import os
import re
import sys
from pathlib import Path
from typing import Optional, List, Union, Dict, overload
import pickle
import nltk
from SAR_semantics import EmbeddingModel, SentenceBertEmbeddingModel, BetoEmbeddingCLSModel, BetoEmbeddingModel, SpacyStaticModel


## UTILIZAR PARA LA AMPLIACION
# Selecciona un modelo semántico
SEMANTIC_MODEL = "SBERT"
#SEMANTIC_MODEL = "BetoCLS"
#SEMANTIC_MODEL = "Beto"
#SEMANTIC_MODEL = "Spacy"
#SEMANTIC_MODEL = "Spacy_noSW_noA"

def create_semantic_model(modelname):
    assert modelname in ("SBERT", "BetoCLS", "Beto", "Spacy", "Spacy_noSW_noA")
    
    if modelname == "SBERT": return SentenceBertEmbeddingModel()    
    elif modelname == "BetoCLS": return BetoEmbeddingCLSModel()
    elif modelname == "Beto": return BetoEmbeddingModel()
    elif modelname == "Spacy": SpacyStaticModel(remove_stopwords=False, remove_noalpha=False)
    return SpacyStaticModel()

class SAR_Indexer:
    """
    Prototipo de la clase para realizar la indexacion y la recuperacion de artículos de Wikipedia
        
        Preparada para todas las ampliaciones:
          posicionales + busqueda semántica + ranking semántico

    Se deben completar los metodos que se indica.
    Se pueden añadir nuevas variables y nuevos metodos
    Los metodos que se añadan se deberan documentar en el codigo y explicar en la memoria
    """

    # campo que se indexa
    DEFAULT_FIELD = 'all'
    # numero maximo de documento a mostrar cuando self.show_all es False
    SHOW_MAX = 10


    all_atribs = ['urls', 'index', 'docs', 'articles', 'tokenizer', 'show_all',
                  "semantic", "chuncks", "embeddings", "chunck_index", "kdtree", "artid_to_emb"]


    def __init__(self):
        """
        Constructor de la clase SAR_Indexer.
        NECESARIO PARA LA VERSION MINIMA

        Incluye todas las variables necesaria pero
        	puedes añadir más variables si las necesitas. 

        """
        self.urls = set() # hash para las urls procesadas,
        self.index: Dict[str, PostingList] = {} # hash para el indice invertido de terminos --> clave: termino, valor: posting list
        self.docs: Dict[int, str] = {} # diccionario de terminos --> clave: entero(docid),  valor: ruta del fichero.
        self.articles: Dict[int, Dict[str, int]] = {} # hash de articulos --> clave entero (artid), valor: la info necesaria para diferencia los artículos dentro de su fichero
        self.tokenizer = re.compile(r"\W+") # expresion regular para hacer la tokenizacion
        self.show_all = False # valor por defecto, se cambia con self.set_showall()

        # PARA LA AMPLIACION
        self.semantic = None
        self.chuncks = []
        self.embeddings = []
        self.chunck_index = []
        self.artid_to_emb = {} # WARN: Sin usar
        self.kdtree = None
        self.semantic_threshold = None
        self.semantic_ranking = None # ¿¿ ranking de consultas binarias ?? # WARN: Sin usar
        self.model: EmbeddingModel | None = None
        self.MAX_EMBEDDINGS = 200 # número máximo de embedding que se extraen del kdtree en una consulta # WARN: Sin usar
        
        
        
        

    ###############################
    ###                         ###
    ###      CONFIGURACION      ###
    ###                         ###
    ###############################


    def set_showall(self, v:bool):
        """

        Cambia el modo de mostrar los resultados.

        input: "v" booleano.

        UTIL PARA TODAS LAS VERSIONES

        si self.show_all es True se mostraran todos los resultados el lugar de un maximo de self.SHOW_MAX, no aplicable a la opcion -C

        """
        self.show_all = v


    def set_semantic_threshold(self, v:float):
        """

        Cambia el umbral para la búsqueda semántica.

        input: "v" booleano.

        UTIL PARA LA AMPLIACIÓN

        si self.semantic es False el umbral no tendrá efecto.

        """
        self.semantic_threshold = v

    def set_semantic_ranking(self, v:bool):
        """

        Cambia el valor de semantic_ranking.

        input: "v" booleano.

        UTIL PARA LA AMPLIACIÓN

        si self.semantic_ranking es True se hará una consulta binaria y los resultados se rankearán por similitud semántica.

        """
        self.semantic_ranking = v


    #############################################
    ###                                       ###
    ###      CARGA Y GUARDADO DEL INDICE      ###
    ###                                       ###
    #############################################


    def save_info(self, filename:str):
        """
        Guarda la información del índice en un fichero en formato binario

        """
        info = [self.all_atribs] + [getattr(self, atr) for atr in self.all_atribs]
        with open(filename, 'wb') as fh:
            pickle.dump(info, fh)

    def load_info(self, filename:str):
        """
        Carga la información del índice desde un fichero en formato binario

        """
        #info = [self.all_atribs] + [getattr(self, atr) for atr in self.all_atribs]
        with open(filename, 'rb') as fh:
            info = pickle.load(fh)
        atrs = info[0]
        for name, val in zip(atrs, info[1:]):
            setattr(self, name, val)


    ###############################
    ###                         ###
    ###   SIMILITUD SEMANTICA   ###
    ###                         ###
    ###############################

            
    def load_semantic_model(self, modelname:str=SEMANTIC_MODEL):
        """
    
        Carga el modelo de embeddings para la búsqueda semántica.
        Solo se debe cargar una vez
        
        """
        if self.model is None:
            print(f"loading {modelname} model ... ",end="", file=sys.stderr)             
            self.model = create_semantic_model(modelname)
            print("done!", file=sys.stderr)

            
    def update_chuncks(self, txt:str, artid:int):
        """
        
        Añade los chuncks (frases en nuestro caso) del texto "txt" correspondiente al articulo "artid" en la lista de chuncks
        Pasos:
            1 - extraer los chuncks de txt, en nuestro caso son las frases. Se debe utilizar "sent_tokenize" de la librería "nltk"
            2 - actualizar los atributos que consideres necesarios: self.chuncks, self.embeddings, self.chunck_index y self.artid_to_emb.
        
        """

        # TODO: Falta:
        # - actualizar self.embeddings y self.emb_to_artid

        sentences = nltk.sent_tokenize(txt, "spanish")
        self.chuncks.append(sentences)
        self.chunck_index.append(artid)


    def create_kdtree(self):
        """
        
        Crea el tktree utilizando un objeto de la librería SAR_semantics
        Solo se debe crear una vez despues de indexar todos los documentos
        
        # 1: Se debe llamar al método fit del modelo semántico
        # 2: Opcionalmente se puede guardar información del modelo semántico (kdtree y/o embeddings) en el SAR_Indexer
        
        """
        print("Creating kdtree ...", end="")
	    
        self.model = create_semantic_model(SEMANTIC_MODEL)
        self.model.fit(self.chuncks)
        self.kdtree = self.model.kdtree
        self.embeddings = self.model.embeddings

        print("done!")


        
    def solve_semantic_query(self, query:str):
        """

        Resuelve una consulta utilizando el modelo semántico.
        Pasos:
            1 - utiliza el método query del modelo sémantico
            2 - devuelve top_k resultados, inicialmente top_k puede ser MAX_EMBEDDINGS
            3 - si el último resultado tiene una distancia <= self.semantic_threshold 
                  ==> no se han recuperado todos los resultado: vuelve a 2 aumentando top_k
            4 - también se puede salir si recuperamos todos los embeddings
            5 - tenemos una lista de chuncks que se debe pasar a artículos
        """

        self.load_semantic_model()

        assert self.embeddings is not None

        articles = list(self.articles.keys()) # obtén los artid
        k = self.MAX_EMBEDDINGS
        while True:
            # `query` devueve una tupla con los embeddings de cada chunk, seguidos del índice de su chunk
            indexed_distances = self.model.query(query, k)
            greatest_distance,_ = indexed_distances[-1]
            # convierte los índices en un set de artículos
            if (
                # si no se ha establecido un threshold, se dan los resultados como buenos...
                self.semantic_threshold is None
                # si se ha establecido, la mayor de las distancias ha de ser menor o igual que él...
                or greatest_distance > self.semantic_threshold
                # pero si se han recuperado todos los embeddings no buscamos más
                or len(indexed_distances) == len(self.embeddings)
            ): break

            # aumenta el máximo de documentos a recuperar en la query
            k *= 2

        # saca los artículos a partir de los índices
        return list(set([articles[i] for _, i in indexed_distances]))


    def semantic_reranking(self, query:str, articles: List[int]):
        """

        Ordena los articulos en la lista 'article' por similitud a la consulta 'query'.
        Pasos:
            1 - utiliza el método query del modelo sémantico
            2 - devuelve top_k resultado, inicialmente top_k puede ser MAX_EMBEDDINGS
            3 - a partir de los chuncks se deben obtener los artículos
            3 - si entre los artículos recuperados NO estan todos los obtenidos por la RI binaria
                  ==> no se han recuperado todos los resultado: vuelve a 2 aumentando top_k
            4 - se utiliza la lista ordenada del kdtree para ordenar la lista "articles"
        """
        
        self.load_semantic_model()

        k = self.MAX_EMBEDDINGS
        while True:
            # `query` devueve una tupla con los embeddings de cada chunk, seguidos del índice de su chunk
            indexed_distances = self.model.query(query, k)
            # convierte los índices en un set de artículos
            retrieved_articles = set([articles[i] for _, i in indexed_distances])
            if not retrieved_articles.difference(articles):
                break

            k *= 2

        return list(retrieved_articles)


    ###############################
    ###                         ###
    ###   PARTE 1: INDEXACION   ###
    ###                         ###
    ###############################

    def already_in_index(self, article:Dict) -> bool:
        """

        Args:
            article (Dict): diccionario con la información de un artículo

        Returns:
            bool: True si el artículo ya está indexado, False en caso contrario
        """
        return article['url'] in self.urls


    def index_dir(self, root:str, **args):
        """

        Recorre recursivamente el directorio o fichero "root"
        NECESARIO PARA TODAS LAS VERSIONES

        Recorre recursivamente el directorio "root"  y indexa su contenido
        los argumentos adicionales "**args" solo son necesarios para las funcionalidades ampliadas

        """
        self.positional = args['positional']
        self.semantic = args['semantic']
        if self.semantic is True:
            self.load_semantic_model()


        file_or_dir = Path(root)

        if file_or_dir.is_file():
            # is a file
            self.index_file(root)
        elif file_or_dir.is_dir():
            # is a directory
            for d, _, files in os.walk(root):
                for filename in sorted(files):
                    if filename.endswith('.json'):
                        fullname = os.path.join(d, filename)
                        self.index_file(fullname)
        else:
            print(f"ERROR:{root} is not a file nor directory!", file=sys.stderr)
            sys.exit(-1)

        # INFO: Para la búsqueda semántica
        self.create_kdtree()

        #####################################################
        ## COMPLETAR SI ES NECESARIO FUNCIONALIDADES EXTRA ##
        #####################################################
        
        
    def parse_article(self, raw_line:str) -> Dict[str, str]:
        """
        Crea un diccionario a partir de una linea que representa un artículo del crawler

        Args:
            raw_line: una linea del fichero generado por el crawler

        Returns:
            Dict[str, str]: claves: 'url', 'title', 'summary', 'all', 'section-name'
        """
        
        article = json.loads(raw_line)
        sec_names = []
        txt_secs = ''
        for sec in article['sections']:
            txt_secs += sec['name'] + '\n' + sec['text'] + '\n'
            txt_secs += '\n'.join(subsec['name'] + '\n' + subsec['text'] + '\n' for subsec in sec['subsections']) + '\n\n'
            sec_names.append(sec['name'])
            sec_names.extend(subsec['name'] for subsec in sec['subsections'])
        article.pop('sections') # no la necesitamos
        article['all'] = article['title'] + '\n\n' + article['summary'] + '\n\n' + txt_secs
        article['section-name'] = '\n'.join(sec_names)

        return article


    def index_file(self, filename:str):
        """

        Indexa el contenido de un fichero.

        input: "filename" es el nombre de un fichero generado por el Crawler cada línea es un objeto json
            con la información de un artículo de la Wikipedia

        NECESARIO PARA TODAS LAS VERSIONES

        dependiendo del valor de self.positional se debe ampliar el indexado

        """

        # calcula el Id del documento y guarda el nombre del fichero asociado.
        # se asume que no se llamará a esta función dos veces para el mismo documento.
        docid = len(self.docs)
        self.docs[docid] = filename

        artid = len(self.articles)

        # itera por los artículos de un fichero
        for i, line in enumerate(open(filename)):
            article = self.parse_article(line)
            if self.already_in_index(article):
                continue

            self.urls.add(article["url"])

            # calcula el Id global del artículo
            artid += 1
            # guarda el índice del documento y la posición relativa en él
            self.articles[artid] = {
                "document": docid,
                "relative_position": i,
            }

            content = article[self.DEFAULT_FIELD]

            # extrae los términos de la cadena ya limpiada
            terms = self.tokenize(content)

            for position, term in enumerate(terms):
                if term not in self.index:
                    self.index[term] = PostingList()

                self.index[term].insert(artid, position if self.positional else None)

            # INFO: Búsqueda semántica
            if self.semantic:
                self.update_chuncks(content, artid)


    def tokenize(self, text:str):
        """
        NECESARIO PARA TODAS LAS VERSIONES

        Tokeniza la cadena "texto" eliminando simbolos no alfanumericos y dividientola por espacios.
        Puedes utilizar la expresion regular 'self.tokenizer'.

        params: 'text': texto a tokenizar

        return: lista de tokens

        """
        return self.tokenizer.sub(' ', text.lower()).split()




    def show_stats(self):
        """
        NECESARIO PARA TODAS LAS VERSIONES

        Muestra estadisticas de los indices

        """

        width = 40
        print( "=" * width)
        print(f"Number of indexed files: {len(self.docs)}")
        print( "-" * width)
        print(f"Number of indexed articles: {len(self.articles)}")
        print( "-" * width)
        print( "TOKENS:")
        print(f"\tNumber of tokens in '{self.DEFAULT_FIELD}': {len(self.index)}")
        print( "-" * width)
        print(f"Positional queries are {'allowed' if self.positional else 'NOT allowed'}.")
        print( "=" * width)



    #################################
    ###                           ###
    ###   PARTE 2: RECUPERACION   ###
    ###                           ###
    #################################

    ###################################
    ###                             ###
    ###   PARTE 2.1: RECUPERACION   ###
    ###                             ###
    ###################################

    def parse_query(self, query: str):
        """
        Convierte la consulta en una lista de strings en la que los substrings rodeados por '"' están juntos
        """
        query_split = query.split()
        query_list: list[str] = []

        i = 0
        while i < len(query_split):
            if query_split[i].startswith('"'):
                s = query_split[i]
                while not query_split[i].endswith('"'):
                    i += 1
                    s += " " + query_split[i]

                # borra los '"' del principio y final
                s = s[1:-1]
                query_list.append(s)
            else:
                query_list.append(query_split[i])

            i += 1

        return query_list

    def solve_query(self, query:str, prev:Dict={}):
        """
        NECESARIO PARA TODAS LAS VERSIONES

        Resuelve una query.
        Debe realizar el parsing de consulta que sera mas o menos complicado en funcion de la ampliacion que se implementen


        param:  "query": cadena con la query
                "prev": incluido por si se quiere hacer una version recursiva. No es necesario utilizarlo.


        return: posting list con el resultado de la query

        """

        if query is None or len(query) == 0:
            return [], None # el `, None` lo piden los tests

        parsed = self.parse_query(query)
        queries = iter(parsed)
        first = next(queries)

        if first == "NOT":
            excluded = next(queries)
            excluded_posting = self.get_posting(excluded).get_list()
            posting_list_acc = self.reverse_posting(excluded_posting)
        else:
            posting_list_acc = self.get_posting(first)

        for q in queries:
            if q == "NOT":
                q = next(queries) # fallará si "NOT" no va seguido de nada
                posting_list_acc -= self.get_posting(q)
            else:
                posting_list_acc &= self.get_posting(q)
        
        return posting_list_acc.get_list(), None # el `, None` lo piden los tests




    def get_posting(self, term:str):
        """

        Devuelve la posting list asociada a un termino.
        Puede llamar self.get_positionals: para las búsquedas posicionales.


        param:  "term": termino del que se debe recuperar la posting list.

        return: posting list

        NECESARIO PARA TODAS LAS VERSIONES

        """
        term = term.lower()
        if len(term.split()) > 1:
            return self.get_positionals(term)
        else:
            return self.index[term] if term in self.index else PostingList()



    def get_positionals(self, terms:str):
        """

        Devuelve la posting list asociada a una secuencia de terminos consecutivos.
        NECESARIO PARA LAS BÚSQUESAS POSICIONALES

        param:  "terms": lista con los terminos consecutivos para recuperar la posting list.

        return: posting list

        """

        terms_iter = iter(terms.split())
        head = next(terms_iter)
        tail = terms_iter

        # guarda los documentos que contienen la sucesión de términos indicada
        positionals = self.get_posting(head)

        for term in tail:
            # busca, para cada uno de los documentos que contienen `term`,
            # en cuáles se suceden las posiciones anteriores y guarda las nuevas posicioens

            term_postings = self.get_posting(term)

            a = positionals.get()
            b = term_postings.get()
            i = j = 0 # índices de `a` y `b`

            positionals = PostingList()

            while i < len(a) and j < len(b):
            # busca los documentos (artículos) que coinciden
                if a[i][0] < b[j][0]:
                    i += 1
                elif a[i][0] > b[j][0]:
                    j += 1
                else:
                    artid = a[i][0]
                    positions_a = a[i][1]
                    positions_b = b[j][1]
                    i += 1
                    j += 1

                    # NOTE: Se asume que ambas listas están ordenadas,
                    # porque las posiciones se insertan de forma ordenada
                    m = n = 0
                    while m < len(positions_a) and n < len(positions_b):
                        # busca las posiciones que se suceden
                        if positions_a[m]+1 < positions_b[n]:
                            m += 1
                        elif positions_a[m]+1 > positions_b[n]:
                            n += 1
                        else:
                            position = positions_b[n] # la posición del sucesivo
                            positionals.insert(artid, position)
                            m += 1
                            n += 1

        return positionals


    def reverse_posting(self, p: list):
        """
        NECESARIO PARA TODAS LAS VERSIONES

        Devuelve una posting list con todas las noticias excepto las contenidas en p.
        Util para resolver las queries con NOT.


        param:  "p": posting list


        return: posting list con todos los artid exceptos los contenidos en p

        """
        
        # crea una PostingList con todos los articulos
        # WARN: lo hace posicional sin importar si el índice es posicional o no
        # si el índice no es posicional, la búsqueda de cadenas rodeadas por '"' fallará.
        # WARN: no tiene en cuenta si es posicional, podría ser un problema
        all_postings = PostingList()
        for posting in self.index.values():
            all_postings |= posting

        # excluye los que coinciden con la query
        return all_postings - PostingList(p)



    def and_posting(self, p1:list, p2:list):
        """
        NECESARIO PARA TODAS LAS VERSIONES

        Calcula el AND de dos posting list de forma EFICIENTE

        param:  "p1", "p2": posting lists sobre las que calcular


        return: posting list con los artid incluidos en p1 y p2

        """

        return PostingList(p1) & PostingList(p2)




    def minus_posting(self, p1, p2):
        """
        OPCIONAL PARA TODAS LAS VERSIONES

        Calcula el except de dos posting list de forma EFICIENTE.
        Esta funcion se incluye por si es util, no es necesario utilizarla.

        param:  "p1", "p2": posting lists sobre las que calcular


        return: posting list con los artid incluidos de p1 y no en p2

        """

        return PostingList(p1) - PostingList(p2)        





    #####################################
    ###                               ###
    ### PARTE 2.2: MOSTRAR RESULTADOS ###
    ###                               ###
    #####################################

    def solve_and_count(self, ql:List[str], verbose:bool=True) -> List:
        results = []
        for query in ql:
            if len(query) > 0 and query[0] != '#':
                r, _ = self.solve_query(query)
                results.append(len(r))
                if verbose:
                    print(f'{query}\t{len(r)}')
            else:
                results.append(0)
                if verbose:
                    print(query)
        return results


    def solve_and_test(self, ql:List[str]) -> bool:
        errors = False
        for line in ql:
            if len(line) > 0 and line[0] != '#':
                query, ref = line.split('\t')
                reference = int(ref)
                result, _ = self.solve_query(query)
                result = len(result)
                if reference == result:
                    print(f'{query}\t{result}')
                else:
                    print(f'>>>>{query}\t{reference} != {result}<<<<')
                    errors = True
            else:
                print(line)

        return not errors


    def solve_and_show(self, query:str):
        """
        NECESARIO PARA TODAS LAS VERSIONES

        Resuelve una consulta y la muestra junto al numero de resultados

        param:  "query": query que se debe resolver.

        return: el numero de artículo recuperadas, para la opcion -T

        """

        result = len(self.solve_query(query))
        print(f"{query}\t{result}")

        return result



class PostingList:

    def __init__(self, postings: list[int] | None = None):
        if postings is None:
            postings = []
        self.postings: Dict[int, list[int]] = {}
        for posting in postings:
            self._append_posting(posting)

    def __and__(self, other: "PostingList"):
        """
        Sobrecarga el operador "&"
        """
        output = PostingList()
        a = self.get()
        b = other.get()
        i = j = 0 # índices de `a` y `b`, respectivamente

        while i < len(a) and j < len(b):
            if a[i][0] > b[j][0]:
                j += 1
            elif a[i][0] < b[j][0]:
                i += 1
            else: # si son iguales
                # inserta los dos para juntar todos los documentos de ambas instancias
                output._append_posting(a[i][0])
                output._append_posting(b[j][0])
                i += 1
                j += 1

        return output

    def __sub__(self, other: "PostingList"):
        """
        Sobrecarga el operador "-"
        """
        output = PostingList()
        a = self.get()
        b = other.get()
        i = j = 0 # índices de `a` y `b`, respectivamente

        while i < len(a) and j < len(b):
            if a[i][0] > b[j][0]:
                # está en B y no en A
                j += 1
            elif a[i][0] < b[j][0]:
                output._append_posting(a[i][0])
                i += 1
            else: # son iguales
                # está en A y en B
                i += 1
                j += 1

        # si quedan elementos en A pero no en B, se añaden todos
        for k in range(i, len(a)):
            output._append_posting(a[k][0])

        return output

    def __or__(self, other: "PostingList"):
        """
        Sobrecarga el operador "|"
        """

        new_postings = self.postings.copy()
        for (posting, _) in other.postings.items():
            self._append_posting(posting, None, new_postings)

        result = PostingList()
        result.postings = new_postings
        return result

    def insert(self, posting: int, position: int | None = None):
        """
        Inserta el posting de forma ordenada
        """
        self._append_posting(posting, position)

    def _append_posting(
        self,
        posting: int,
        position: int | None = None,
        posting_list: Dict[int, list[int]] | None = None,
    ):
        if posting_list is None:
            posting_list = self.postings

        if posting not in posting_list:
            posting_list[posting] = []

        if position is not None:
            posting_list[posting].append(position)


    def get(self):
        """
        Devuelve, de forma ordenada, una lista que representa una posting list,
        donde cada ítem es una tupla con el posting y las posiciones en las que se encuentra.
        """
        return sorted(self.postings.items(), key=lambda i: i[0])

    def get_list(self):
        """
        Devuelve, de forma ordenada, una lista que representa una posting list,
        cuyos ítems son los postings.
        """
        return [p[0] for p in self.get()]

