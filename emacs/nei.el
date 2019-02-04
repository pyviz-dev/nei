(require 'cl-lib) ;; For keyword argument support
(require 'websocket)
(require 'json)

(require 'nei-parse)
(require 'nei-edit)
(require 'nei-commands)
(require 'nei-server)


(defvar ws-connection nil
  "The websocket client connection.")

(defvar ws-messages nil
  "Messages received over the websocket connection.")

(defvar nei--unexpected-disconnect nil
  "Flag indicating whether the websocket connection is closed or not")

(defvar nei--execution-count 0
  "The number of kernel executions invoked from NEI")

(defvar nei-browser "firefox"
  "The browser used by NEI when launch new tabs.")



(defun nei--open-websocket ()
  (progn
    (setq conn (websocket-open
                "ws://127.0.0.1:9999"
                :on-message (lambda (_websocket frame)
                              (push (websocket-frame-text frame) ws-messages)
                              (message "ws frame: %S" (websocket-frame-text frame))
                              (error "Test error (expected)"))
                :on-close (lambda (_websocket) (setq nei--unexpected-disconnect t))
                ;; New connection, reset execution count.
                :on-open (lambda (_websocket) (setq nei--execution-count 0)))
          )
    (setq ws-connection conn)
    )
  )

(defun nei--open-ws-connection (&optional quiet)
  "Opens a new websocket connection if needed"
  (if (or (null ws-connection) nei--unexpected-disconnect)
      (progn
        (setq nei--unexpected-disconnect nil)
        (nei--open-websocket)
        )
    (if (not quiet)
        (message "Websocket connection already open")
      )
    )
  )


(defun nei-connect ()
  "Start the NEI server, establish the websocket connection and begin mirroring"
  (interactive)
  (nei--start-server)
  (nei--open-ws-connection)
  (nei-start-mirroring)
  )

(defun nei-disconnect ()
  "Close the websocket and shutdown the server"
  (interactive)
  (nei--close-ws-connection)
  (nei--stop-nei-server)
  )

(defun nei--close-ws-connection ()
  "Close the websocket connection."
  (websocket-close ws-connection)
  (setq ws-connection nil)
  )


(defun nei--disconnection-error ()
  (nei-stop-mirroring)
  (websocket-close ws-connection)
  (message "Unexpected disconnection")
  (setq nei--unexpected-disconnect nil)
  )


  )

;;========================;;
;; Sending data to server ;;
;;========================;;


(defun nei--send-data (text &optional warn-no-connection)
  "Runs the callback if there is a connection and handles unexpected disconnects."
  (cond (nei--unexpected-disconnect (nei--disconnection-error))
        ((null ws-connection) (if warn (message "Not connected to NEI server")))
        (t (progn
             (websocket-send-text ws-connection text)
             (if nei--unexpected-disconnect (nei--disconnection-error)))
           )
        )
  )

(defun nei--send-json (obj &optional warn-no-connection)
    "JSON encode an object and send it over the websocket connection."
    (nei--send-data (json-encode obj) warn-no-connection)
    )



(defun nei-bindings (map)
  ;; Capitalized commands
  (define-key map (kbd "C-c W") 'nei-write-notebook)
  (define-key map (kbd "C-c I") 'nei-insert-notebook)
  (define-key map (kbd "C-c E") 'nei-exec-by-line)
  (define-key map (kbd "C-c L") 'nei-clear-all-cell-outputs)
  (define-key map (kbd "C-c C") 'nei-update-css)
  
  (define-key map (kbd "C-c w") 'nei-move-cell-up)
  (define-key map (kbd "C-c s") 'nei-move-cell-down)
  (define-key map (kbd "C-c <down>") 'nei-move-point-to-next-cell)
  (define-key map (kbd "C-c <up>") 'nei-move-point-to-previous-cell)
  (define-key map (kbd "C-c c") 'nei-insert-code-cell)
  (define-key map (kbd "C-c m") 'nei-insert-markdown-cell)
  (define-key map (kbd "C-c e") 'nei-exec-by-line-and-move-to-next-cell)
  (define-key map (kbd "C-c i") 'nei-interrupt-kernel)
  (define-key map (kbd "C-c r") 'nei-restart-kernel)
  (define-key map (kbd "C-c l") 'nei-clear-cell-by-line)
  (define-key map (kbd "C-c n") 'nei-clear-notebook-and-restart)

  (define-key map (kbd "C-c v") 'nei-view-browser)
  (define-key map (kbd "C-c V") 'nei-view-notebook)

  (define-key map (kbd "C-c ,") 'nei-scroll-up)
  (define-key map (kbd "C-c .") 'nei-scroll-down)
  map
)



(define-minor-mode nei-mode
  "Nei for authoring notebooks in Emacs."
  :lighter " NEI"
  
  :keymap (let ((map (make-sparse-keymap)))
            (nei-bindings map))

  (if (not nei-external-server)
      (progn
        (nei-update-config)
        (nei-start-mirroring)
        )
    )
  (nei-fontify)

  )
  


(defun nei--enable-python-mode-advice (&optional arg)
  "Enable Python major mode when nei enabled if necessary"
  (if (not (string= major-mode "python-mode"))
      (python-mode))
  )
(advice-add 'nei-mode :before #'nei--enable-python-mode-advice)


;; Future ideas
;; C-c f for 'focus on cell'
;; C-c p for 'ping cell' to scroll to cell.


(provide 'nei)