;;; doctor-es.el --- ayuda psicológica para usuarios frustrados  -*- lexical-binding: t -*-

;; Copyright (C) 1985-2025 Free Software Foundation, Inc.

;; Maintainer: emacs-devel@gnu.org
;; Keywords: games

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; El punto de entrada único `doctor-es', simula a un analista rogeriano usando
;; técnicas de producción de frases similares a la clásica demostración ELIZA
;; de pseudo-IA.

;;; Code:

(defvar doctor--**mad**)
(defvar doctor--*print-space*)
(defvar doctor--*print-upcase*)
(defvar doctor--abuselst)
(defvar doctor--abusewords)
(defvar doctor--afraidof)
(defvar doctor--arerelated)
(defvar doctor--areyou)
(defvar doctor--bak)
(defvar doctor--beclst)
(defvar doctor--bother)
(defvar doctor--bye)
(defvar doctor--canyou)			; unused?
(defvar doctor--chatlst)
(defvar doctor--continue)
(defvar doctor--deathlst)
(defvar doctor--describe)
(defvar doctor--drnk)
(defvar doctor--drugs)
(defvar doctor--eliza-flag)
(defvar doctor--elizalst)
(defvar doctor--famlst)
(defvar doctor--feared)
(defvar doctor--fears)
(defvar doctor--feelings-about)
(defvar doctor--foullst)
(defvar doctor-found)
(defvar doctor--hello)
(defvar doctor--history)
(defvar doctor--howareyoulst)
(defvar doctor--howdyflag)
(defvar doctor--huhlst)
(defvar doctor--ibelieve)
(defvar doctor--improve)
(defvar doctor--inter)
(defvar doctor--isee)
(defvar doctor--isrelated)
(defvar doctor--lincount)
(defvar doctor--longhuhlst)
(defvar doctor--lover)
(defvar doctor--machlst)
(defvar doctor--mathlst)
(defvar doctor--maybe)
(defvar doctor--moods)
(defvar doctor--neglst)
(defvar doctor-obj)
(defvar doctor-object)
(defvar doctor-owner)
(defvar doctor--please)
(defvar doctor--problems)
(defvar doctor--qlist)
(defvar doctor--random-adjective)
(defvar doctor--relation)
(defvar doctor--remlst)
(defvar doctor--repetitive-shortness)
(defvar doctor--replist)
(defvar doctor--rms-flag)
(defvar doctor--schoollst)
(defvar doctor-sent)
(defvar doctor--sexlst)
(defvar doctor--shortbeclst)
(defvar doctor--shortlst)
(defvar doctor--something)
(defvar doctor--sportslst)
(defvar doctor--stallmanlst)
(defvar doctor--states)
(defvar doctor-subj)
(defvar doctor--suicide-flag)
(defvar doctor--sure)
(defvar doctor--thing)
(defvar doctor--things)
(defvar doctor--thlst)
(defvar doctor--toklst)
(defvar doctor--typos)
(defvar doctor-verb)
(defvar doctor--want)
(defvar doctor--whatwhen)
(defvar doctor--whereoutp)
(defvar doctor--whysay)
(defvar doctor--whywant)
(defvar doctor--zippy-flag)
(defvar doctor--zippylst)

(defun doc// (x) x)

(defmacro doc$ (what)
  "Quoted arg form of `doctor-$'."
  `(doctor-$ ',what))

(defun doctor-$ (what)
  "Return the car of a list, rotating the list each time."
  (let* ((vv (symbol-value what))
	(first (car vv))
	(ww (append (cdr vv) (list first))))
    (set what ww)
    first))

(defvar doctor-es-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "\n" 'doctor-ret-or-read)
    (define-key map "\r" 'doctor-ret-or-read)
    (define-key map [return] 'doctor-ret-or-read)
    (define-key map "\C-j" 'doctor-read-print)
    map)
  "Keymap for Doctor-ES mode.")

;; Actually defined in textconv.c.
(defvar text-conversion-style)

(define-derived-mode doctor-es-mode text-mode "Doctor-ES"
  "Modo para ejecutar el Doctor (Eliza) en español.
Como el modo Texto con Auto Fill
excepto que RET después de una nueva línea, o LFD en cualquier momento,
lee la frase antes del punto, e imprime la respuesta del Doctor."
  (setq-local doctor-es-mode-map doctor-es-mode-map)
  (local-set-key (kbd "RET") 'doctor-ret-or-read)
  (local-set-key (kbd "C-j") 'doctor-read-print)
  (modify-syntax-entry ?á "w" doctor-es-mode-syntax-table)
  (modify-syntax-entry ?é "w" doctor-es-mode-syntax-table)
  (modify-syntax-entry ?í "w" doctor-es-mode-syntax-table)
  (modify-syntax-entry ?ó "w" doctor-es-mode-syntax-table)
  (modify-syntax-entry ?ú "w" doctor-es-mode-syntax-table)
  (modify-syntax-entry ?ñ "w" doctor-es-mode-syntax-table)
  (modify-syntax-entry ?Á "w" doctor-es-mode-syntax-table)
  (modify-syntax-entry ?É "w" doctor-es-mode-syntax-table)
  (modify-syntax-entry ?Í "w" doctor-es-mode-syntax-table)
  (modify-syntax-entry ?Ó "w" doctor-es-mode-syntax-table)
  (modify-syntax-entry ?Ú "w" doctor-es-mode-syntax-table)
  (modify-syntax-entry ?Ñ "w" doctor-es-mode-syntax-table)
  (doctor-make-variables)
  (turn-on-auto-fill)
  (setq text-conversion-style 'action)
  (doctor-type '(yo soy el psicoterapeuta \.
		 (doc$ doctor--please) (doc$ doctor--describe) sus (doc$ doctor--problems) \.
		 cada vez que termine de hablar\, pulse RET dos veces \.))
  (insert "\n"))

(defun doctor-make-variables ()
  (setq-local doctor--typos
              (mapcar (lambda (x)
                        (put (car x) 'doctor-correction  (cadr x))
                        (put (cadr x) 'doctor-expansion (car (cddr x)))
                        (car x))
                      '((estoy e\'stoy (estoy))
                        (tmb tambie\'n (también))
                        (q que (que))
                        (pq porque (porque))
                        (pk porque (porque))
                        (eres e\'res (soy))
                        (estás esta\'s (estoy))
                        (soy s\'oy (eres)))))
  (setq-local doctor-sent nil)
  (setq-local doctor-found nil)
  (setq-local doctor-owner nil)
  (setq-local doctor--history nil)
  (setq-local doctor--inter '((bueno\,)
                              (hmmm \.\.\.\ así que\,)
                              (entonces)
                              (\.\.\.y)
                              (luego)))
  (setq-local doctor--continue '((continúe)
                                 (proceda)
                                 (siga)
                                 (continúe hablando)))
  (setq-local doctor--relation
              '((su relación con)
                (algo que recuerde sobre)
                (sus sentimientos hacia)
                (algunas experiencias que haya tenido con)
                (cómo se siente respecto a)))
  (setq-local doctor--fears
              '(((doc$ doctor--whysay) tiene (doc$ doctor--afraidof) (doc// doctor--feared) \?)
                (parece aterrorizado por (doc// doctor--feared) \.)
                (¿cuándo empezó a sentir (doc$ doctor--afraidof) (doc// doctor--feared) \?)))
  (setq-local doctor--sure '((seguro)
                             (positivo)
                             (cierto)
                             (absolutamente seguro)))
  (setq-local doctor--afraidof '((miedo de)
                                 (temor por)
                                 (miedo a)))
  (setq-local doctor--areyou '((es usted)
                               (ha estado)
                               (se siente)))
  (setq-local doctor--isrelated
              '((tiene algo que ver con)
                (está relacionado con)
                (podría ser la razón de)
                (es causado por)
                (es debido a)))
  (setq-local doctor--arerelated '((tienen algo que ver con)
                                   (están relacionados con)
                                   (podrían haber causado)
                                   (podrían ser la razón de)
                                   (son causados por)
                                   (son debido a)))
  (setq-local doctor--moods
              '(((doc$ doctor--areyou) (doc// doctor-found) a menudo \?)
                (¿qué le hace estar (doc// doctor-found) \?)
                ((doc$ doctor--whysay) está (doc// doctor-found) \?)))
  (setq-local doctor--maybe '((tal vez)
                              (quizás)
                              (posiblemente)))
  (setq-local doctor--whatwhen '((qué pasó cuando)
                                 (qué pasaría si)))
  (setq-local doctor--hello '((¿cómo está \?)
                              (hola \.)
                              (¡buenas!)
                              (hola \.)
                              (hola \.)
                              (hola qué tal \.)))
  (setq-local doctor--drnk
              '((¿bebe mucho (doc// doctor-found) \?)
                (¿se emborracha a menudo \?)
                ((doc$ doctor--describe) sus hábitos con la bebida \.)))
  (setq-local doctor--drugs
              '((¿usa (doc// doctor-found) a menudo \?)
                (¿es (doc$ doctor--areyou) adicto a (doc// doctor-found) \?)
                (¿se da cuenta de que las drogas pueden ser muy perjudiciales \?)
                ((doc$ doctor--maybe) debería intentar dejar de usar (doc// doctor-found) \.)))
  (setq-local doctor--whywant
              '(((doc$ doctor--whysay) (doc// doctor-subj) podría (doc$ doctor--want) (doc// doctor-obj) \?)
                (¿cómo se siente al querer \?)
                (¿por qué debería (doc// doctor-subj) obtener (doc// doctor-obj) \?)
                (¿cuándo (doc// doctor-subj) empezó a (doc$ doctor--want) (doc// doctor-obj) \?)
                (¿está (doc$ doctor--areyou) obsesionado con (doc// doctor-obj) \?)
                (¿por qué debería darle (doc// doctor-obj) a (doc// doctor-subj) \?)
                (¿ha obtenido alguna vez (doc// doctor-obj) \?)))
  (setq-local doctor--canyou
              '((por supuesto que puedo \.)
                (¿por qué debería hacerlo \?)
                (¿qué le hace pensar que yo querría hacerlo \?)
                (soy el doctor\, puedo hacer lo que me plazca \.)
                (no realmente\, no depende de mí \.)
                (depende\, ¿qué tan importante es \?)
                (podría\, pero no creo que fuera prudente hacerlo \.)
                (¿puede usted \?)
                (tal vez pueda\, tal vez no \.\.\.)
                (no creo que deba hacer eso \.)))
  (setq-local doctor--want '((querer) (desear) (anhelar) (querer) (esperar)))
  (setq-local doctor--shortlst
              '((¿puede dar más detalles sobre eso \?)
                ((doc$ doctor--please) continúe \.)
                (siga\, no tenga miedo \.)
                (necesito un poco más de detalle por favor \.)
                (está siendo un poco breve\, (doc$ doctor--please) entre en detalles \.)
                (¿puede ser más explícito \?)
                (¿y \?)
                ((doc$ doctor--please) entre en más detalles \?)
                (¡no está muy hablador hoy!)
                (¿eso es todo \?)
                (¿por qué responde tan brevemente \?)))
  (setq-local doctor--famlst
              '((cuénteme (doc$ doctor--something) sobre (doc// doctor-owner) familia \.)
                (parece insistir en (doc// doctor-owner) familia \.)
                (¿está (doc$ doctor--areyou) obsesionado con (doc// doctor-owner) familia \?)))
  (setq-local doctor--huhlst
              '(((doc$ doctor--whysay) (doc// doctor-sent) \?)
                (¿es por (doc$ doctor--things) que dice (doc// doctor-sent) \?)))
  (setq-local doctor--longhuhlst
              '(((doc$ doctor--whysay) eso \?)
                (no le entiendo \.)
                ((doc$ doctor--thlst))
                (¿tiene (doc$ doctor--areyou) (doc$ doctor--afraidof) eso \?)))
  (setq-local doctor--feelings-about '((sentimientos sobre)
                                       (aprensiones hacia)
                                       (pensamientos sobre)
                                       (emociones hacia)))
  (setq-local doctor--random-adjective
              '((vívido)
                (emocionalmente estimulante)
                (excitante)
                (aburrido)
                (interesante)
                (reciente)
                (aleatorio)
                (inusual)
                (impactante)
                (vergonzoso)))
  (setq-local doctor--whysay '((¿por qué dice)
                               (¿qué le hace creer)
                               (¿está seguro de que)
                               (¿realmente piensa)
                               (¿qué le hace pensar)))
  (setq-local doctor--isee '((ya veo \.\.\.)
                             (sí\,)
                             (comprendo \.)
                             (ah \.) ))
  (setq-local doctor--please '((por favor\,)
                               (le agradecería que)
                               (tal vez podría)
                               (por favor\,)
                               (¿podría por favor)
                               (¿por qué no)
                               (podría)))
  (setq-local doctor--bye
              '((mi secretaria le enviará la factura \.)
                (adiós \.)
                (nos vemos \.)
                (bien\, hablaremos en otro momento \.)
                (hasta luego \.)
                (bien\, diviértase \.)
                (ciao \.)))
  (setq-local doctor--something '((algo)
                                  (más)
                                  (cómo se siente)))
  (setq-local doctor--thing '((su vida)
                              (su vida sexual)))
  (setq-local doctor--things '((sus asuntos)
                               (la gente con la que sale)
                               (asuntos del trabajo)
                               (cualquier pasatiempo que tenga)
                               (complejos que tenga)
                               (sus inhibiciones)
                               (algunos problemas en su infancia)
                               (algunos problemas en casa)))
  (setq-local doctor--describe '((describa)
                                 (cuénteme sobre)
                                 (hable de)
                                 (discuta)
                                 (dígame más sobre)
                                 (entre en detalles sobre)))
  (setq-local doctor--ibelieve
              '((creo que) (pienso que) (tengo la sensación de que) (me parece que)
                (parece que)))
  (setq-local doctor--problems '((problemas)
                                 (inhibiciones)
                                 (complejos)
                                 (dificultades)
                                 (ansiedades)
                                 (frustraciones)))
  (setq-local doctor--bother '((¿le molesta que)
                               (¿le molesta que)
                               (¿se arrepintió alguna vez)
                               (¿lamenta)
                               (¿está satisfecho con el hecho de que)))
  (setq-local doctor--machlst
              '((parece que tiene la mente en (doc// doctor-found) \.)
                (piensa demasiado en (doc// doctor-found) \.)
                (debería intentar dejar de pensar en (doc// doctor-found)\.)
                (¿es usted un hacker \?)))
  (setq-local doctor--qlist
              '((¿qué piensa usted \?)
                (¡yo haré las preguntas\, si no le importa!)
                (yo mismo podría preguntar lo mismo \.)
                ((doc$ doctor--please) permítame hacer las preguntas \.)
                (me he hecho esa pregunta muchas veces \.)
                ((doc$ doctor--please) intente responder a esa pregunta usted mismo \.)))
  (setq-local doctor--foullst
              '(((doc$ doctor--please) ¡cuide su lenguaje!)
                ((doc$ doctor--please) evite esos pensamientos tan insanos \.)
                ((doc$ doctor--please) no sea tan vulgar \.)
                (no se aprecia tal lascivia \.)))
  (setq-local doctor--deathlst
              '((esta no es una forma saludable de pensar \.)
                ((doc$ doctor--bother) usted también morirá algún día \?)
                (¡me preocupa su obsesión con este tema!)
                (¿veía mucha violencia en la televisión de niño \?)))
  (setq-local doctor--sexlst
              '(((doc$ doctor--areyou) (doc$ doctor--afraidof) el sexo \?)
                ((doc$ doctor--describe) (doc$ doctor--something) sobre su historia sexual \.)
                ((doc$ doctor--please) (doc$ doctor--describe) su vida sexual \.\.\.)
                ((doc$ doctor--describe) sus (doc$ doctor--feelings-about) su pareja sexual \.)
                ((doc$ doctor--describe) su experiencia sexual más (doc$ doctor--random-adjective) \.)
                ((doc$ doctor--areyou) satisfecho con (doc// doctor--lover) \.\.\. \?)))
  (setq-local doctor--neglst '((¿por qué no \?)
                               ((doc$ doctor--bother) se lo pregunte \?)
                               (¿por qué no \?)
                               (¿por qué no \?)
                               (¿cómo es eso \?)
                               ((doc$ doctor--bother) se lo pregunte \?)))
  (setq-local doctor--beclst
              '((¿es porque (doc// doctor-sent) que vino a mí \?)
                ((doc$ doctor--bother) (doc// doctor-sent) \?)
                (¿cuándo supo por primera vez que (doc// doctor-sent) \?)
                (¿es el hecho de que (doc// doctor-sent) la verdadera razón \?)
                (¿explica algo más el hecho de que (doc// doctor-sent) \?)
                (¿está (doc$ doctor--areyou) (doc$ doctor--sure) (doc// doctor-sent) \? )))
  (setq-local doctor--shortbeclst
              '(((doc$ doctor--bother) se lo pregunte \?)
                (¡eso no es mucha respuesta!)
                ((doc$ doctor--inter) ¿por qué no quiere hablar de ello \?)
                (¡hable más alto!)
                (¿tiene (doc$ doctor--areyou) (doc$ doctor--afraidof) hablar de ello \?)
                (no tenga (doc$ doctor--afraidof) dar detalles \.)
                ((doc$ doctor--please) entre en más detalles \.)))
  (setq-local doctor--thlst
              '(((doc$ doctor--maybe) (doc$ doctor--thing) (doc$ doctor--isrelated) esto \.)
                ((doc$ doctor--maybe) (doc$ doctor--things) (doc$ doctor--arerelated) esto \.)
                (¿es por (doc$ doctor--things) que está pasando por todo esto \?)
                (¿cómo concilia (doc$ doctor--things) \? )
                ((doc$ doctor--maybe) esto (doc$ doctor--isrelated) (doc$ doctor--things) \?)))
  (setq-local doctor--remlst
              '((antes dijo (doc$ doctor--history) \?)
                (mencionó que (doc$ doctor--history) \?)
                ((doc$ doctor--whysay) (doc$ doctor--history) \? )))
  (setq-local doctor--toklst
              '((¿es así como se relaja \?)
                (¿cuánto tiempo lleva fumando hierba \?)
                (¿tiene (doc$ doctor--areyou) (doc$ doctor--afraidof) de verse arrastrado a usar cosas más duras \?)))
  (setq-local doctor--states
              '((¿se pone (doc// doctor-found) a menudo \?)
                (¿disfruta estando (doc// doctor-found) \?)
                (¿qué le hace estar (doc// doctor-found) \?)
                (¿con qué frecuencia (doc$ doctor--areyou) (doc// doctor-found) \?)
                (¿cuándo fue la última vez que estuvo (doc// doctor-found) \?)))
  (setq-local doctor--replist '((yo . (usted))
                                (mi . (su))
                                (mí . (usted))
                                (me . (le))
                                (nos . (les))
                                (usted . (yo))
                                (su . (mi))
                                (tuyo . (mío))
                                (mío . (tuyo))
                                (nuestro . (su))
                                (nosotros . (ustedes))
                                (no-sé . (no lo sé))
                                (no\, . ())
                                (sí\, . ())
                                (venga . (voy))
                                (tengo-que . (tiene que))
                                (nunca . (no nunca))
                                (no-puede . (no puede))
                                (estoy . (está))
                                (estás . (estoy))
                                (soy . (es))
                                (eres . (soy))
                                (mis . (sus))
                                (sus . (mis))
                                (míos . (tuyos))
                                (tuyos . (míos))
                                (nuestros . (sus))
                                (aquí . (allí))
                                (por-favor . ())
                                (ah\, . ())
                                (ah . ())
                                (oh\, . ())
                                (oh . ())))
  (setq-local doctor--stallmanlst
              '(((doc$ doctor--describe) sus (doc$ doctor--feelings-about) él \.)
                (¿es (doc$ doctor--areyou) amigo de Stallman \?)
                (¿le (doc$ doctor--bother) que Stallman sea (doc$ doctor--random-adjective) \?)
                ((doc$ doctor--ibelieve) usted le tiene (doc$ doctor--afraidof) \.)))
  (setq-local doctor--schoollst
              '(((doc$ doctor--describe) su (doc// doctor-found) \.)
                (¿le (doc$ doctor--bother) que las cosas pudieran (doc$ doctor--improve) \?)
                (¿cree que esto tiene que ver con su carrera \?)
                ((doc$ doctor--maybe) esto (doc$ doctor--isrelated) con su actitud profesional \.)
                ((doc$ doctor--maybe) debería dedicar más tiempo a (doc$ doctor--something) \.)))
  (setq-local doctor--improve
              '((mejorar) (ser mejores) (haber mejorado) (ser más altas)))
  (setq-local doctor--elizalst
              '(((doc$ doctor--areyou) (doc$ doctor--sure) \?)
                ((doc$ doctor--ibelieve) tiene (doc$ doctor--problems) con (doc// doctor-found) \.)
                ((doc$ doctor--whysay) (doc// doctor-sent) \?)))
  (setq-local doctor--sportslst
              '((cuénteme (doc$ doctor--something) sobre (doc// doctor-found) \.)
                ((doc$ doctor--describe) (doc$ doctor--relation) (doc// doctor-found) \.)
                (¿encuentra (doc// doctor-found) (doc$ doctor--random-adjective) \?)))
  (setq-local doctor--mathlst
              '(((doc$ doctor--describe) (doc$ doctor--something) sobre las matemáticas \.)
                ((doc$ doctor--maybe) sus (doc$ doctor--problems) (doc$ doctor--arerelated) (doc// doctor-found) \.)
                (no sé mucho de (doc// doctor-found) \, pero (doc$ doctor--continue)
                   de todos modos \.)))
  (setq-local doctor--zippylst
              '(((doc$ doctor--areyou) Zippy \?)
                ((doc$ doctor--ibelieve) tiene algunos (doc$ doctor--problems) serios \.)
                (¿le (doc$ doctor--bother) ser un cabeza de chorlito \?)))
  (setq-local doctor--chatlst
              '(((doc$ doctor--maybe) podríamos charlar \.)
                ((doc$ doctor--please) (doc$ doctor--describe) (doc$ doctor--something) sobre el modo chat \.)
                (¿le (doc$ doctor--bother) que nuestra discusión sea tan (doc$ doctor--random-adjective) \?)))
  (setq-local doctor--abuselst
              '(((doc$ doctor--please) intente ser menos abusivo \.)
                ((doc$ doctor--describe) por qué me llama (doc// doctor-found) \.)
                (¡ya he tenido suficiente de usted!)))
  (setq-local doctor--abusewords
              '(aburrido payaso torpe cretino tonto
                        necio idiota imbécil estúpido
                        perdedor asqueroso luser
                        nerd oaf asco estúpido twit))
  (setq-local doctor--howareyoulst
              '((cómo estás) (cómo va) (qué tal)
                (cómo le va) (qué pasa) (qué hay de nuevo)
                (cómo va todo) (cómo está)
                (qué me cuenta) (cómo te va)))
  (setq-local doctor--whereoutp '(huh remem rthing))
  (setq-local doctor-subj nil)
  (setq-local doctor-verb nil)
  (setq-local doctor-obj nil)
  (setq-local doctor--feared nil)
  (setq-local doctor--repetitive-shortness '(0 . 0))
  (setq-local doctor--**mad** nil)
  (setq-local doctor--rms-flag nil)
  (setq-local doctor--eliza-flag nil)
  (setq-local doctor--zippy-flag nil)
  (setq-local doctor--suicide-flag nil)
  (setq-local doctor--lover '(su pareja))
  (setq-local doctor--bak nil)
  (setq-local doctor--lincount 0)
  (setq-local doctor--*print-upcase* nil)
  (setq-local doctor--*print-space* nil)
  (setq-local doctor--howdyflag nil)
  (setq-local doctor-object nil))

;; Define equivalence classes of words that get treated alike.

(defun doctor-meaning (x) (get x 'doctor-meaning))

(defmacro doctor-put-meaning (symb val)
  "Store the base meaning of a word on the property list."
  `(put ',symb 'doctor-meaning ,val))

(doctor-put-meaning hola 'howdy)
(doctor-put-meaning buenas 'howdy)
(doctor-put-meaning saludos 'howdy)
(doctor-put-meaning qué-tal 'howdy)
(doctor-put-meaning computador 'mach)
(doctor-put-meaning computadora 'mach)
(doctor-put-meaning ordenador 'mach)
(doctor-put-meaning máquinas 'mach)
(doctor-put-meaning máquina 'mach)
(doctor-put-meaning ia 'mach)
(doctor-put-meaning inteligencia 'mach)
(doctor-put-meaning artificial 'mach)
(doctor-put-meaning trabajo 'school)
(doctor-put-meaning jefe 'family)
(doctor-put-meaning jefa 'family)
(doctor-put-meaning empresa 'school)
(doctor-put-meaning oficina 'school)
(doctor-put-meaning gnu 'mach)
(doctor-put-meaning linux 'mach)
(doctor-put-meaning mierda 'foul)
(doctor-put-meaning cabrón 'foul)
(doctor-put-meaning maldito 'foul)
(doctor-put-meaning joder 'foul)
(doctor-put-meaning asco 'foul)
(doctor-put-meaning puta 'foul)
(doctor-put-meaning porquería 'foul)
(doctor-put-meaning porro 'toke)
(doctor-put-meaning hierba 'toke)
(doctor-put-meaning maría 'toke)
(doctor-put-meaning marihuana 'toke)
(doctor-put-meaning pastillas 'drug)
(doctor-put-meaning droga 'drug)
(doctor-put-meaning cocaína 'drug)
(doctor-put-meaning ama 'loves)
(doctor-put-meaning amar 'love)
(doctor-put-meaning amaba 'love)
(doctor-put-meaning odia 'hates)
(doctor-put-meaning odiar 'hate)
(doctor-put-meaning odiaba 'hate)
(doctor-put-meaning borracho 'state)
(doctor-put-meaning colocado 'state)
(doctor-put-meaning feliz 'state)
(doctor-put-meaning paranoico 'state)
(doctor-put-meaning deseo 'desire)
(doctor-put-meaning deseo 'desire)
(doctor-put-meaning quiero 'desire)
(doctor-put-meaning desear 'desire)
(doctor-put-meaning gusta 'desire)
(doctor-put-meaning espero 'desire)
(doctor-put-meaning necesito 'desire)
(doctor-put-meaning frustrado 'mood)
(doctor-put-meaning deprimido 'mood)
(doctor-put-meaning molesto 'mood)
(doctor-put-meaning triste 'mood)
(doctor-put-meaning emocionado 'mood)
(doctor-put-meaning preocupado 'mood)
(doctor-put-meaning solo 'mood)
(doctor-put-meaning enfadado 'mood)
(doctor-put-meaning celoso 'mood)
(doctor-put-meaning miedo 'fear)
(doctor-put-meaning aterrado 'fear)
(doctor-put-meaning susto 'fear)
(doctor-put-meaning fobia 'fear)
(doctor-put-meaning sexo 'sexnoun)
(doctor-put-meaning condón 'sexnoun)
(doctor-put-meaning esposa 'family)
(doctor-put-meaning familia 'family)
(doctor-put-meaning hermanos 'family)
(doctor-put-meaning hermanas 'family)
(doctor-put-meaning padres 'family)
(doctor-put-meaning hermano 'family)
(doctor-put-meaning hermana 'family)
(doctor-put-meaning padre 'family)
(doctor-put-meaning madre 'family)
(doctor-put-meaning marido 'family)
(doctor-put-meaning primos 'family)
(doctor-put-meaning abuela 'family)
(doctor-put-meaning abuelo 'family)
(doctor-put-meaning matar 'death)
(doctor-put-meaning muerte 'death)
(doctor-put-meaning morir 'death)
(doctor-put-meaning suicidio 'death)
(doctor-put-meaning muerto 'death)
(doctor-put-meaning dolor 'symptoms)
(doctor-put-meaning fiebre 'symptoms)
(doctor-put-meaning enfermo 'symptoms)
(doctor-put-meaning náuseas 'symptoms)
(doctor-put-meaning tos 'symptoms)
(doctor-put-meaning alcohol 'alcohol)
(doctor-put-meaning vino 'alcohol)
(doctor-put-meaning cerveza 'alcohol)
(doctor-put-meaning ron 'alcohol)
(doctor-put-meaning ginebra 'alcohol)
(doctor-put-meaning follar 'sexverb)
(doctor-put-meaning besar 'sexverb)
(doctor-put-meaning beso 'sexverb)
(doctor-put-meaning porque 'conj)
(doctor-put-meaning pero 'conj)
(doctor-put-meaning aunque 'conj)
(doctor-put-meaning hasta 'when)
(doctor-put-meaning cuando 'when)
(doctor-put-meaning mientras 'when)
(doctor-put-meaning desde 'when)
(doctor-put-meaning colegio 'school)
(doctor-put-meaning escuela 'school)
(doctor-put-meaning universidad 'school)
(doctor-put-meaning notas 'school)
(doctor-put-meaning profesor 'school)
(doctor-put-meaning profesora 'school)
(doctor-put-meaning matemáticas 'math)
(doctor-put-meaning examen 'school)
(doctor-put-meaning deberes 'school)
(doctor-put-meaning charlar 'chat)

;;;###autoload
(defun doctor-es ()
  "Cambia al búfer *doctor-es* y comienza a dar psicoterapia en español."
  (interactive)
  (switch-to-buffer "*doctor-es*")
  (doctor-es-mode))

(defun doctor-ret-or-read (arg)
  "Insert a newline if preceding character is not a newline.
Otherwise call the Doctor to parse preceding sentence."
  (interactive "*p" doctor-es-mode)
  (if (= (preceding-char) ?\n)
      (doctor-read-print)
    (newline arg)))

(defun doctor-read-print ()
  "Top level loop."
  (interactive nil doctor-es-mode)
  (setq doctor-sent (doctor-readin))
  (insert "\n")
  (setq doctor--lincount (1+ doctor--lincount))
  (doctor-doc)
  (insert "\n")
  (setq doctor--bak doctor-sent))

(defun doctor-readin ()
  "Read a sentence.  Return it as a list of words."
  (let (sentence)
    (forward-line -1)
    (beginning-of-line)
    (while (not (eobp))
      (let ((opoint (point))
            (token (doctor-read-token)))
        (if (not (equal token '||))
            (setq sentence (append sentence (list token))))
        (if (= opoint (point))
            (forward-char 1))))
    sentence))

(defun doctor-read-token ()
  "Read one word from buffer."
  (prog1 (intern (downcase (buffer-substring (point)
					     (progn
					       (forward-word 1)
					       (point)))))
    (skip-syntax-forward "^w")))

;; Main processing function for sentences that have been read.

(defun doctor-doc ()
  (cond
   ((equal doctor-sent '(foo))
    (doctor-type '(¡bar! (doc$ doctor--please) (doc$ doctor--continue) \.)))
   ((member doctor-sent doctor--howareyoulst)
    (doctor-type '(estoy bien \. (doc$ doctor--describe) cómo está usted \.)))
   ((or (member doctor-sent '((adiós) (hasta luego) (me voy) (chao)
			      (vete) (lárgate)))
	(memq (car doctor-sent)
	      '(adiós para detén para detener salir)))
    (doctor-type (doc$ doctor--bye)))
   ((and (eq (car doctor-sent) 'usted)
	 (memq (cadr doctor-sent) doctor--abusewords))
    (setq doctor-found (cadr doctor-sent))
    (doctor-type (doc$ doctor--abuselst)))
   ((eq (car doctor-sent) 'quésignifica)
    (doctor-def (cadr doctor-sent)))
   ((equal doctor-sent '(analizar))
    (doctor-type (list  'sujeto '= doctor-subj ",  "
			'verbo '= doctor-verb "\n"
			'frase 'objeto '= doctor-obj ","
			'forma 'nominal '=  doctor-object "\n"
			'palabra 'clave 'actual 'es doctor-found
			", "
			'posesivo 'más 'reciente
			'es doctor-owner "\n"
			'frase 'usada 'fue
			"..."
			'(doc// doctor--bak))))
   ((memq (car doctor-sent) '(eres es hace tiene tienen cómo cuándo dónde quién porqué))
    (doctor-type (doc$ doctor--qlist)))
   ;;   ((eq (car sent) 'forget)
   ;;    (set (cadr sent) nil)
   ;;    (doctor-type '((doc$ doctor--isee) (doc$ doctor--please)
   ;;     (doc$ doctor--continue)\.)))
   (t
    (if (doctor-defq doctor-sent) (doctor-define doctor-sent doctor-found))
    (if (> (length doctor-sent) 12)
	(setq doctor-sent (doctor-shorten doctor-sent)))
    (setq doctor-sent (doctor-correct-spelling
		       (doctor-replace doctor-sent doctor--replist)))
    (cond ((equal (car doctor-sent) 'yow) (doctor-zippy))
	  ((< (length doctor-sent) 2)
	   (cond ((eq (doctor-meaning (car doctor-sent)) 'howdy)
		  (doctor-howdy))
		 (t (doctor-short))))
	  (t
	   (setq doctor-sent (doctor-fixup doctor-sent))
	   (if (eq (car doctor-sent) 'no)
	       (cond ((zerop (random 3))
		      (doctor-type '(¿tiene (doc$ doctor--afraidof) eso \?)))
		     ((zerop (random 2))
		      (doctor-type '(¡no me diga qué hacer \! ¡yo soy el
					    doctor aquí!))
		      (doctor-rthing))
		     (t
		      (doctor-type '((doc$ doctor--whysay) que no debería
				     (cddr doctor-sent)
				     \?))))
	     (doctor-go (doctor-wherego doctor-sent))))))))

;; Things done to process sentences once read.

(defun doctor-correct-spelling (sent)
  "Correct the spelling and expand each word in sentence."
  (if sent
      (apply 'append (mapcar (lambda (word)
				(if (memq word doctor--typos)
				    (get (get word 'doctor-correction)
					 'doctor-expansion)
				  (list word)))
			     sent))))

(defun doctor-shorten (sent)
  "Make a sentence manageably short using a few hacks."
  (let (foo
	(retval sent)
	(temp '(porque pero sin-embargo además de-todos-modos hasta
		    mientras que excepto por-qué cómo)))
    (while temp
	   (setq foo (memq (car temp) sent))
	   (if (and foo
		    (> (length foo) 3))
	       (setq retval (doctor-fixup foo)
		     temp nil)
	       (setq temp (cdr temp))))
    retval))

(defun doctor-define (sent found)
  (doctor-svo sent found 1 nil)
  (and
   (doctor-nounp doctor-subj)
   (not (doctor-pronounp doctor-subj))
   doctor-subj
   (doctor-meaning doctor-object)
   (put doctor-subj 'doctor-meaning (doctor-meaning doctor-object))
   t))

(defun doctor-defq (sent)
  "Set global var DOCTOR-FOUND to first keyword found in sentence SENT."
  (setq doctor-found nil)
  (let ((temp '(significa aplica refiere relacionado
		      similar definido asociado vinculado como mismo)))
    (while temp
	   (if (memq (car temp) sent)
	       (setq doctor-found (car temp)
		     temp nil)
	       (setq temp (cdr temp)))))
  doctor-found)

(defun doctor-def (x)
  (doctor-type (list 'the 'word x 'means (doctor-meaning x) 'to 'me))
  nil)

(defun doctor-forget ()
  "Delete the last element of the history list."
  (setq doctor--history (reverse (cdr (reverse doctor--history)))))

(defun doctor-query (x)
  "Prompt for a line of input from the minibuffer until a noun or verb is seen.
Put dialogue in buffer."
  (let (a
	(prompt (concat (doctor-make-string x)
			" what ?  "))
	retval)
    (while (not retval)
	   (while (not a)
	     (insert ?\n
		     prompt
		     (read-string prompt)
		     ?\n)
	     (setq a (doctor-readin)))
	   (while (and a (not retval))
		  (cond ((doctor-nounp (car a))
			 (setq retval (car a)))
			((doctor-verbp (car a))
			 (setq retval (doctor-build
				       (doctor-build x " ")
				       (car a))))
			((setq a (cdr a))))))
    retval))

(defun doctor-subjsearch (sent key type)
  "Search for the subject of a sentence SENT, looking for the noun closest
to and preceding KEY by at least TYPE words.  Set global variable `doctor-subj'
to the subject noun, and return the portion of the sentence following it."
  (let ((i (- (length sent) (length (memq key sent)) type)))
    (while (and (> i -1) (not (doctor-nounp (nth i sent))))
      (setq i (1- i)))
    (cond ((> i -1)
	   (setq doctor-subj (nth i sent))
	   (nthcdr (1+ i) sent))
	  (t
	   (setq doctor-subj 'usted)
	   nil))))

(defun doctor-nounp (x)
  "Return non-nil if the symbol argument is a noun."
	(or (doctor-pronounp x)
	    (not (or (doctor-verbp x)
		     (equal x 'not)
		     (doctor-prepp x)
		     (doctor-modifierp x) )) ))

(defun doctor-pronounp (x)
  "Return non-nil if the symbol argument is a pronoun."
  (memq x '(
	yo mí mío conmigo
	nosotros nos nosotras
	usted ustedes su suyo suya
	él ella ello
	esto eso aquello cosas cosa
	ellos ellas
	alguien nadie alguno
	todo algo nada)))

(dolist (x
         '(amar amo amas ama amamos aman
           odiar odio odias odia odiamos odian
           querer quiero quieres quiere queremos quieren
           desear deseo deseas desea deseamos desean
           necesitar necesito necesitas necesita necesitamos necesitan
           sentir siento sientes siente sentimos sienten
           creer creo crees cree creemos creen
           pensar pienso piensas piensa pensamos piensan
           parecer parezco pareces parece parecemos parecen
           ir voy vas va vamos van
           venir vengo vienes viene venimos vienen
           hacer hago haces hace hacemos hacen
           tener tengo tienes tiene tenemos tienen
           ser soy eres es somos son
           estar estoy estás está estamos están
           decir digo dices dice decimos dicen
           ver veo ves ve vemos ven
           oír oigo oyes oye oímos oyen
           saber sé sabes sabe sabemos saben
           poder puedo puedes puede podemos pueden
           beber bebo bebes bebe bebemos beben
           tomar tomo tomas toma tomamos toman
           fumar fumo fumas fuma fumamos fuman
           morir muero mueres muere morimos mueren
           matar mato matas mata matamos matan
           hablar hablo hablas habla hablamos hablan
           contar cuento cuentas cuenta contamos cuentan
           explicar explico explicas explica explicamos explican
           entender entiendo entiendes entiende entendemos entienden
           comprender comprendo comprendes comprende comprendemos comprenden
           estudiar estudio estudias estudia estudiamos estudian
           mejorar mejoro mejoras mejora mejoramos mejoran
           molestar molesta molestan molestó
           preocupar preocupa preocupan preocupó
           follar follo follas folla follamos follan
           besar beso besas besa besamos besan))
   (put x 'doctor-sentence-type 'verb))

(defun doctor-verbp (x) (if (symbolp x)
			    (eq (get x 'doctor-sentence-type) 'verb)))

(defun doctor-plural (x)
  "Form the plural of the word argument in Spanish."
  (let ((foo (doctor-make-string x)))
    (cond ((string-match "[aeiouáéíóú]$" foo)
	   (intern (concat foo "s")))
	  (t (intern (concat foo "es"))))))

(defun doctor-setprep (sent key)
  (let ((val)
	(foo (memq key sent)))
    (cond ((null foo) 'algo)
	  ((doctor-prepp (cadr foo))
	   (setq val (doctor-getnoun (cddr foo)))
	   (cond (val val)
		 (t 'algo)))
	  ((doctor-articlep (cadr foo))
	   (setq val (doctor-getnoun (cddr foo)))
	   (cond (val (doctor-build (doctor-build (cadr foo) " ") val))
		 (t 'algo)))
	  (t 'algo))))

(defun doctor-getnoun (x)
  (cond ((null x) (setq doctor-object 'algo))
	((atom x) (setq doctor-object x))
	((eq (length x) 1)
	 (setq doctor-object (cond
		       ((doctor-nounp (setq doctor-object (car x))) doctor-object)
		       (t (doctor-query doctor-object)))))
	((eq (car x) 'a)
	 (doctor-build 'a\  (doctor-getnoun (cdr x))))
	((doctor-prepp (car x))
	 (doctor-getnoun (cdr x)))
	((not (doctor-nounp (car x)))
	 (doctor-build (doctor-build (cdr (assq (car x)
						(append
						 '((un . este)
						   (alguno . este)
						   (uno . aquel))
						 (list
						  (cons
						   (car x) (car x))))))
				     " ")
		       (doctor-getnoun (cdr x))))
	(t (setq doctor-object (car x))
	   (doctor-build (doctor-build (car x) " ") (doctor-getnoun (cdr x))))
	))

(defun doctor-modifierp (x)
  (or (doctor-adjectivep x)
      (doctor-adverbp x)
      (doctor-othermodifierp x)))

(defun doctor-adjectivep (x)
  (or (numberp x)
      (doctor-nmbrp x)
      (doctor-articlep x)
      (doctor-colorp x)
      (doctor-sizep x)
      (doctor-possessivepronounp x)))

(defun doctor-adverbp (xx)
  (let ((xxstr (doctor-make-string xx)))
    (and (>= (length xxstr) 5)
	 (string-equal (substring xxstr -5) "mente"))))

(defun doctor-articlep (x)
  (memq x '(el la los las un una unos unas)))

(defun doctor-nmbrp (x)
  (memq x '(uno dos tres cuatro cinco seis siete ocho nueve diez
		once doce trece catorce quince
		dieciséis diecisiete dieciocho diecinueve
		veinte treinta cuarenta cincuenta sesenta setenta ochenta noventa
		cien mil millón billón
		medio cuarto
		primero segundo tercero cuarto quinto
		sexto séptimo octavo noveno décimo)))

(defun doctor-colorp (x)
  (memq x '(beige negro azul marrón carmesí
		  gris verde
		  naranja rosa púrpura rojo canela
		  violeta blanco amarillo)))

(defun doctor-sizep (x)
  (memq x '(grande largo alto gordo ancho grueso
		pequeño bajo delgado flaco)))

(defun doctor-possessivepronounp (x)
  (memq x '(mi su mis sus nuestro nuestra)))

(defun doctor-othermodifierp (x)
  (memq x '(todo también siempre divertido cualquier malo
		hermoso mejor bien claro
		nunca cada fantástico gracioso
		bueno genial asqueroso pero ignorante
		menos muchos mucho
		agradable odioso pobre real rico
		similar estúpido súper soberbio
		terrible terrorífico demasiado total muy)))

(defun doctor-prepp (x)
  (memq x '(sobre encima después alrededor como en
		antes debajo detrás al-lado-de entre por
		para de dentro-de hacia
		cerca de en sobre por
		a través-de hasta hacia)))

(defun doctor-remember (thing)
  (cond ((null doctor--history)
	 (setq doctor--history (list thing)))
	(t (setq doctor--history (append doctor--history (list thing))))))

(defun doctor-type (x)
  (setq x (doctor-fix-2 x))
  (doctor-txtype (doctor-assm x)))

(defun doctor-fixup (sent)
  (setq sent (append
	      (cdr
	       (assq (car sent)
		     (append
		      '((me  yo)
			(él  él)
			(ella  ella)
			(ellos  ellos)
			(vale)
			(bueno)
			(suspiro)
			(hmm)
			(hmmm)
			(hmmmm)
			(hmmmmm)
			(vaya)
			(seguro)
			(genial)
			(oh)
			(bien)
			(ok)
			(no))
		      (list (list (car sent)
				  (car sent))))))
	      (cdr sent)))
  (doctor-fix-2 sent))

(defun doctor-fix-2 (sent)
  (let ((foo sent))
    (while foo
      (cond ((eq (car foo) 'usted)
	     (cond ((memq (cadr foo) '(soy estoy tengo quiero))
		    (rplaca (cdr foo)
			    (cdr (assq (cadr foo)
				       '((soy . es) (estoy . está)
					 (tengo . tiene) (quiero . quiere))))))
		   ))
	    ((equal (car foo) 'yo)
	     (cond ((memq (cadr foo) '(es está tiene quiere))
		    (rplaca (cdr foo)
			    (cdr (assq (cadr foo)
				       '((es . soy) (está . estoy)
					 (tiene . tengo) (quiere . quiero))))))
		   )))
	(setq foo (cdr foo)))
    sent))

(defun doctor-vowelp (x)
  (memq x '(?a ?e ?i ?o ?u)))

(defun doctor-replace (sent rlist)
  "Replace any element of SENT that is the car of a replacement
element pair in RLIST."
  (apply 'append
	 (mapcar
	   (lambda (x)
	     (cdr (or (assq x rlist)   ; either find a replacement
		      (list x x))))    ; or fake an identity mapping
	   sent)))

(defun doctor-wherego (sent)
  (cond ((null sent) (doc$ doctor--whereoutp))
	((null (doctor-meaning (car sent)))
	 (doctor-wherego (cond ((zerop (random 2))
				(reverse (cdr sent)))
			       (t (cdr sent)))))
	(t
	 (setq doctor-found (car sent))
	 (doctor-meaning (car sent)))))

(defun doctor-svo (sent key type mem)
  "Find subject, verb and object in sentence SENT with focus on word KEY.
TYPE is number of words preceding KEY to start looking for subject.
MEM is t if results are to be put on Doctor's memory stack.
Return in the global variables DOCTOR-SUBJ, DOCTOR-VERB, DOCTOR-OBJECT,
and DOCTOR-OBJ."
  (let ((foo (doctor-subjsearch sent key type)))
    (or foo
	(setq foo sent
	      mem nil))
    (while (and (null (doctor-verbp (car foo))) (cdr foo))
      (setq foo (cdr foo)))
    (setq doctor-verb (car foo))
    (setq doctor-obj (doctor-getnoun (cdr foo)))
    (cond ((eq doctor-object 'i) (setq doctor-object 'me))
	  ((eq doctor-subj 'me) (setq doctor-subj 'i)))
    (cond (mem (doctor-remember (list doctor-subj doctor-verb doctor-obj))))))

(defun doctor-possess (sent key)
  "Set possessive in SENT for keyword KEY.
Hack on previous word, setting global variable DOCTOR-OWNER to correct result."
  (let* ((i (- (length sent) (length (memq key sent)) 1))
	 (prev (if (< i 0) 'su
		 (nth i sent))))
    (setq doctor-owner
	  (if (or (doctor-possessivepronounp prev)
		  (string-equal "s"
				(substring (doctor-make-string prev)
					   -1)))
	      prev
	    'su))))

;; Output of replies.

(defun doctor-txtype (ans)
  "Output to buffer a list of symbols or strings as a sentence."
  (setq doctor--*print-upcase* t doctor--*print-space* nil)
  (let (last-word)
    (while ans
      (let ((current-word (doctor-make-string (car ans))))
        (unless (and last-word
                     (string-equal (downcase last-word) (downcase current-word)))
          (doctor-type-symbol current-word)
          (setq last-word current-word))
        (setq ans (cdr ans)))))
  (insert "\n"))

(defun doctor-type-symbol (word)
  "Output a symbol to the buffer with some fancy case and spacing hacks."
  (setq word (doctor-make-string word))
  (when doctor--*print-upcase*
    (if (string-match "^[¿¡]" word)
        (let ((rest (substring word 1)))
          (setq word (concat (substring word 0 1) (capitalize rest))))
      (setq word (capitalize word))))
  (if (and doctor--*print-upcase* doctor--*print-space*)
      (insert " "))
  (cond ((or (string-match "^[.,;:?!¿¡ ]" word)
	     (not doctor--*print-space*))
	 (insert word))
	(t (insert ?\s word)))
  (and auto-fill-function
       (> (current-column) fill-column)
       (apply auto-fill-function nil))
  (setq doctor--*print-upcase* (string-match "[.?!]$" word)
	doctor--*print-space* t))

(defun doctor-build (str1 str2)
  "Make a symbol out of the concatenation of the two non-list arguments."
  (cond ((null str1) str2)
	((null str2) str1)
	((and (atom str1)
	      (atom str2))
	 (intern (concat (doctor-make-string str1)
			 (doctor-make-string str2))))
	(t nil)))

(defun doctor-make-string (obj)
  (cond ((stringp obj) obj)
	((symbolp obj) (symbol-name obj))
	((numberp obj) (int-to-string obj))
	(t "")))

(defun doctor-concat (x y)
  "Like append, but force atomic arguments to be lists."
  (append
   (if (and x (atom x)) (list x) x)
   (if (and y (atom y)) (list y) y)))

(defun doctor-assm (proto)
  (cond ((null proto) nil)
	((atom proto) (list proto))
	((atom (car proto))
	 (cons (car proto) (doctor-assm (cdr proto))))
	(t (doctor-concat (doctor-assm (eval (car proto))) (doctor-assm (cdr proto))))))

;; Functions that handle specific words or meanings when found.

(defun doctor-go (destination)
  "Call a `doctor-*' function."
  (funcall (intern (concat "doctor-" (doctor-make-string destination)))))

(defun doctor-desire1 ()
  (doctor-go (doc$ doctor--whereoutp)))

(defun doctor-huh ()
  (cond ((< (length doctor-sent) 9) (doctor-type (doc$ doctor--huhlst)))
	(t (doctor-type (doc$ doctor--longhuhlst)))))

(defun doctor-rthing () (doctor-type (doc$ doctor--thlst)))

(defun doctor-remem () (cond ((null doctor--history) (doctor-huh))
			     ((doctor-type (doc$ doctor--remlst)))))

(defun doctor-howdy ()
  (cond ((not doctor--howdyflag)
	 (doctor-type '((doc$ doctor--hello) ¿qué le trae por aquí \?))
	 (setq doctor--howdyflag t))
	(t
	 (doctor-type '((doc$ doctor--ibelieve) ya nos hemos presentado \.))
	 (doctor-type '((doc$ doctor--please) (doc$ doctor--describe) (doc$ doctor--things) \.)))))

(defun doctor-when ()
  (cond ((< (length (memq doctor-found doctor-sent)) 3) (doctor-short))
	(t
	 (setq doctor-sent (cdr (memq doctor-found doctor-sent)))
	 (setq doctor-sent (doctor-fixup doctor-sent))
	 (doctor-type '((doc$ doctor--whatwhen) (doc// doctor-sent) \?)))))

(defun doctor-conj ()
  (cond ((< (length (memq doctor-found doctor-sent)) 4) (doctor-short))
	(t
	 (setq doctor-sent (cdr (memq doctor-found doctor-sent)))
	 (setq doctor-sent (doctor-fixup doctor-sent))
	 (cond ((eq (car doctor-sent) 'de)
		(doctor-type '(¿está (doc$ doctor--sure) de que esa es la verdadera razón \?))
		(setq doctor--things (cons (cdr doctor-sent) doctor--things)))
	       (t
		(doctor-remember doctor-sent)
		(doctor-type (doc$ doctor--beclst)))))))

(defun doctor-short ()
  (cond ((= (car doctor--repetitive-shortness) (1- doctor--lincount))
	 (rplacd doctor--repetitive-shortness
		 (1+ (cdr doctor--repetitive-shortness))))
	(t
	 (rplacd doctor--repetitive-shortness 1)))
  (rplaca doctor--repetitive-shortness doctor--lincount)
  (cond ((> (cdr doctor--repetitive-shortness) 6)
	 (cond ((not doctor--**mad**)
		(doctor-type '((doc$ doctor--areyou)
			       solo intentando ver qué palabras
			       tengo en mi vocabulario \? ¡por favor intente
			       mantener una conversación razonable!))
		(setq doctor--**mad** t))
	       (t
		(doctor-type '(me rindo \. usted necesita una lección de
				 escritura creativa \.\.\.))
		)))
	(t
	 (cond ((equal doctor-sent (doctor-assm '(sí)))
		(doctor-type '((doc$ doctor--isee) (doc$ doctor--inter) (doc$ doctor--whysay) esto es así \?)))
	       ((equal doctor-sent (doctor-assm '(porque)))
		(doctor-type (doc$ doctor--shortbeclst)))
	       ((equal doctor-sent (doctor-assm '(no)))
		(doctor-type (doc$ doctor--neglst)))
	       (t (doctor-type (doc$ doctor--shortlst)))))))

(defun doctor-alcohol () (doctor-type (doc$ doctor--drnk)))

(defun doctor-desire ()
  (let ((foo (memq doctor-found doctor-sent)))
    (cond ((< (length foo) 2)
	   (doctor-go (doctor-build (doctor-meaning doctor-found) 1)))
	  ((memq (cadr foo) '(un una unos unas))
	   (rplacd foo (append '(el tener) (cdr foo)))
	   (doctor-svo doctor-sent doctor-found 1 nil)
	   (doctor-remember (list doctor-subj 'le 'gustaría doctor-obj))
	   (doctor-type (doc$ doctor--whywant)))
	  ((not (eq (cadr foo) 'a))
	   (doctor-go (doctor-build (doctor-meaning doctor-found) 1)))
	  (t
	   (doctor-svo doctor-sent doctor-found 1 nil)
	   (doctor-remember (list doctor-subj 'le 'gustaría doctor-obj))
	   (doctor-type (doc$ doctor--whywant))))))

(defun doctor-drug ()
  (doctor-type (doc$ doctor--drugs))
  (doctor-remember (list 'usted 'usó doctor-found)))

(defun doctor-toke ()
  (doctor-type (doc$ doctor--toklst)))

(defun doctor-state ()
  (doctor-type (doc$ doctor--states)) (doctor-remember (list 'usted 'estuvo doctor-found)))

(defun doctor-mood ()
  (doctor-type (doc$ doctor--moods)) (doctor-remember (list 'usted 'se 'sintió doctor-found)))

(defun doctor-fear ()
  (setq doctor--feared (doctor-setprep doctor-sent doctor-found))
  (doctor-type (doc$ doctor--fears))
  (doctor-remember (list 'usted 'tenía 'miedo 'de doctor--feared)))

(defun doctor-hate ()
  (doctor-svo doctor-sent doctor-found 1 t)
  (cond ((memq 'no doctor-sent) (doctor-forget) (doctor-huh))
	((equal doctor-subj 'usted)
	 (doctor-type '(¿por qué (doc// doctor-verb) (doc// doctor-obj) \?)))
	(t (doctor-type '((doc$ doctor--whysay) (list doctor-subj doctor-verb doctor-obj))))))

(defun doctor-symptoms ()
  (doctor-type '((doc$ doctor--maybe) debería consultar a un médico\;
                 yo soy un psicoterapeuta \.)))

(defun doctor-hates ()
  (doctor-svo doctor-sent doctor-found 1 t)
  (doctor-hates1))

(defun doctor-hates1 ()
  (doctor-type '((doc$ doctor--whysay) (list doctor-subj doctor-verb doctor-obj) \?)))

(defun doctor-loves ()
  (doctor-svo doctor-sent doctor-found 1 t)
  (doctor-qloves))

(defun doctor-qloves ()
  (doctor-type '((doc$ doctor--bother) (list doctor-subj doctor-verb doctor-obj) \?)))

(defun doctor-love ()
  (doctor-svo doctor-sent doctor-found 1 t)
  (cond ((memq 'not doctor-sent) (doctor-forget) (doctor-huh))
	((memq 'to doctor-sent) (doctor-hates1))
	(t
	 (cond ((equal doctor-object 'algo)
		(setq doctor-object '(esta persona que ama))))
	 (cond ((equal doctor-subj 'usted)
		(setq doctor--lover doctor-obj)
		(cond ((equal doctor--lover '(esta persona que ama))
		       (setq doctor--lover '(su pareja))
		       (doctor-forget)
		       (doctor-type '(¿de quién está enamorado \?)))
		      ((doctor-type '((doc$ doctor--please)
				      (doc$ doctor--describe)
				      (doc$ doctor--relation)
				      (doc// doctor--lover)
				      \.)))))
	       ((equal doctor-subj 'yo)
		(doctor-txtype '(¡estábamos hablando de usted!)))
	       (t (doctor-forget)
		  (setq doctor-obj 'alguien)
		  (setq doctor-verb (doctor-build doctor-verb 's))
		  (doctor-qloves))))))

(defun doctor-mach ()
  (setq doctor-found (doctor-plural doctor-found))
  (doctor-type (doc$ doctor--machlst)))

(defun doctor-sexnoun () (doctor-sexverb))

(defun doctor-sexverb ()
  (if (or (memq 'me doctor-sent) (memq 'mí doctor-sent) (memq 'yo doctor-sent))
      (doctor-foul)
    (doctor-type (doc$ doctor--sexlst))))

(defun doctor-death ()
  (cond (doctor--suicide-flag (doctor-type (doc$ doctor--deathlst)))
	((or (equal doctor-found 'suicidio)
             (and (or (equal doctor-found 'matar)
                      (equal doctor-found 'muerte))
                  (memq 'usted doctor-sent)))
	 (setq doctor--suicide-flag t)
         (doctor-type '( Si realmente tiene pensamientos suicidas\, por favor
                         busque ayuda profesional inmediatamente \.
                         Puede contactar con servicios de emergencia o
                         líneas de prevención del suicidio en su país \.
                         (doc$ doctor--please) (doc$ doctor--continue) \.)))
	(t (doctor-type (doc$ doctor--deathlst)))))

(defun doctor-foul ()
  (doctor-type (doc$ doctor--foullst)))

(defun doctor-family ()
  (doctor-possess doctor-sent doctor-found)
  (doctor-type (doc$ doctor--famlst)))

;; I did not add this -- rms.
;; But he might have removed it.  I put it back.  --roland
(defun doctor-rms ()
  (cond (doctor--rms-flag (doctor-type (doc$ doctor--stallmanlst)))
	(t (setq doctor--rms-flag t) (doctor-type '(¿conoce usted a Stallman \?)))))

(defun doctor-school nil (doctor-type (doc$ doctor--schoollst)))

(defun doctor-eliza ()
  (cond (doctor--eliza-flag (doctor-type (doc$ doctor--elizalst)))
	(t (setq doctor--eliza-flag t)
	   (doctor-type '((doc// doctor-found) \? hah !
			  (doc$ doctor--please) (doc$ doctor--continue) \.)))))

(defun doctor-sports () (doctor-type (doc$ doctor--sportslst)))

(defun doctor-math () (doctor-type (doc$ doctor--mathlst)))

(defun doctor-zippy ()
  (cond (doctor--zippy-flag (doctor-type (doc$ doctor--zippylst)))
	(t (setq doctor--zippy-flag t)
	   (doctor-type '(¡vaya! ¿ya somos interactivos \?)))))


(defun doctor-chat () (doctor-type (doc$ doctor--chatlst)))

(provide 'doctor-es)
