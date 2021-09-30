;;; publish.el --- Build and Org blog -*- lexical-binding: t -*-

;; Copyright (C) 2018 Pierre Neidhardt <mail@ambrevar.xyz>
;; Copyright (C) 2021 Joseph Cooper <josephcooperiii@gmail.com>

;; Author: Joseph Cooper <josephcooperiii@gmail.com>
;; Maintainer: Joseph Cooper <josephcooperiii@gmail.com>
;; URL: https://github.com/jrciii/jrciii.github.io
;; Version: 0.0.1
;; Package-Requires: ((emacs "26.1"))
;; Keywords: hypermedia, blog, feed, rss

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Original Author: Pierre Neidhardt <mail@ambrevar.xyz>
;; Original Maintainer: Pierre Neidhardt <mail@ambrevar.xyz>
;; Original URL: https://gitlab.com/Ambrevar/ambrevar.gitlab.io
;;
;; Original Commentary:
;;
;; The entry point is `jrciii/publish': run it to prodice the website.
;;
;; Inspirations include https://gitlab.com/pages/org-mode and various websites
;; listed in source/blog-architecture/index.org.

;;; Code:
;; TODO: Load this file as .dir-locals for .org files so that we can org-publish from there?

(require 'ox-publish)
(require 'seq)

(defvar jrciii/repository "https://github.com/jrciii/jrciii.github.io")
(defvar jrciii/root (expand-file-name "."))

;; Timestamps can be used to avoid rebuilding everything.
;; This is useful locally for testing.
;; It won't work on Gitlab when stored in ./: the timestamps file should
;; probably be put inside the public/ directory.  It's not so useful there
;; however since generation is fast enough.
(setq org-publish-use-timestamps-flag t
      org-publish-timestamp-directory "./")

;; Get rid of index.html~ and the like that pop up during generation.
(setq make-backup-files nil)

(setq org-export-with-section-numbers nil
      org-export-with-smart-quotes t
      org-export-with-email t
      org-export-with-date t
      org-export-with-tags 'not-in-toc
      org-export-with-toc nil
      org-fontify-whole-heading-line t)

(defun jrciii/git-creation-date (file)
  "Return the first commit date of FILE.
Format is %Y-%m-%d."
  (with-temp-buffer
    (call-process "git" nil t nil "log" "--reverse" "--date=short" "--pretty=format:%cd" file)
    (goto-char (point-min))
    (buffer-substring-no-properties (line-beginning-position) (line-end-position))))

(defun jrciii/git-last-update-date (file)
  "Return the last commit date of FILE.
Format is %Y-%m-%d."
  (with-output-to-string
    (with-current-buffer standard-output
      (call-process "git" nil t nil "log" "-1" "--date=short" "--pretty=format:%cd" file))))

(defun jrciii/org-html-format-spec (info)
  "Return format specification for preamble and postamble.
INFO is a plist used as a communication channel.
Just like `org-html-format-spec' but uses git to return creation and last update
dates.
The extra `u` specifier displays the creation date along with the last update
date only if they differ."
  (let* ((timestamp-format (plist-get info :html-metadata-timestamp-format))
         (file (plist-get info :input-file))
         (meta-date (org-export-data (org-export-get-date info timestamp-format)
                                     info))
         (creation-date (if (string= "" meta-date)
                            (jrciii/git-creation-date file)
                          ;; Default to the #+DATE value when specified.  This
                          ;; can be useful, for instance, when Git gets the file
                          ;; creation date wrong if the file was renamed.
                          meta-date))
         (last-update-date (jrciii/git-last-update-date file)))
    `((?t . ,(org-export-data (plist-get info :title) info))
      (?s . ,(org-export-data (plist-get info :subtitle) info))
      (?d . ,creation-date)
      (?T . ,(format-time-string timestamp-format))
      (?a . ,(org-export-data (plist-get info :author) info))
      (?e . ,(mapconcat
	      (lambda (e) (format "<a href=\"mailto:%s\">%s</a>" e e))
	      (split-string (plist-get info :email)  ",+ *")
	      ", "))
      (?c . ,(plist-get info :creator))
      (?C . ,last-update-date)
      (?v . ,(or (plist-get info :html-validation-link) ""))
      (?u . ,(if (string= creation-date last-update-date)
                 creation-date
               (format "%s (<a href=%s>Last update: %s</a>)"
                       creation-date
                       (format "%s/commits/master/%s" jrciii/repository (file-relative-name file jrciii/root))
                       last-update-date))))))
(advice-add 'org-html-format-spec :override 'jrciii/org-html-format-spec)

(defun jrciii/preamble (info)
  "Return preamble as a string."
  (let* ((file (plist-get info :input-file))
         (prefix (file-relative-name (expand-file-name "source" jrciii/root)
                                     (file-name-directory file))))
    (format
     "<a href=\"%1$s/index.html\">Home</a>
<a href=\"%1$s/posts.html\">Posts</a>
<a href=\"%1$s/knowledge/index.html\">Knowledge</a>
<a href=\"%1$s/ticklers/ticklers.html\">Ticklers</a>
<a href=\"%1$s/about/about.html\">About</a>
<a href=\"%1$s/contact/contact.html\">Contact</a>
<a href=\"%2$s\">Comments</a>" prefix jrciii/repository)))

(setq ;; org-html-divs '((preamble "header" "top")
      ;;                 (content "main" "content")
      ;;                 (postamble "footer" "postamble"))
      org-html-postamble nil
      org-html-postamble-format `(("en" ,(concat "<p class=\"comments\"><a href=\""
                                                 jrciii/repository "/issues\">Comments</a></p>")))
      ;; Use custom preamble function to compute relative links.
      org-html-preamble #'jrciii/preamble
      ;; org-html-container-element "section"
      org-html-metadata-timestamp-format "%Y-%m-%d"
      org-html-checkbox-type 'html
      org-html-html5-fancy t
      ;; Use custom .css.  This removes the dependency on `htmlize', but then we
      ;; don't get colored code snippets.
      ;; org-html-htmlize-output-type nil
      org-html-validation-link nil
      org-html-doctype "html5")

(defun jrciii/org-publish-sitemap (title list)
  "Jrciii's site map, as a string.
See `org-publish-sitemap-default'. "
  ;; Remove index and non articles.
  (print list)
  (setcdr list (seq-filter
                (lambda (file)
                  (string-match "file:posts/.*[.]org" (car file)))
                (cdr list)))
  ;; TODO: Include subtitle?  It may be wiser, at least for projects.
  (concat "#+TITLE: " title "\n"
          "#+HTML_HEAD: <link rel=\"stylesheet\" type=\"text/css\" href=\"luxury.css\">"
          "\n"
          ;;"#+HTML_HEAD: <link rel=\"icon\" type=\"image/x-icon\" href=\"logo.png\"> "
          ;;"\n"
          ;;"#+HTML_HEAD: <link href=\"atom.xml\" type=\"application/atom+xml\" rel=\"alternate\" title=\"jrciii's homepage\">"
          (org-list-to-org list)))

(defun jrciii/org-publish-find-date (file project)
  "Find the date of FILE in PROJECT.
Just like `org-publish-find-date' but do not fall back on file
system timestamp and return nil instead."
  (let ((file (org-publish--expand-file-name file project)))
    (or (org-publish-cache-get-file-property file :date nil t)
	(org-publish-cache-set-file-property
	 file :date


	   (let ((date (org-publish-find-property file :date project)))
	     ;; DATE is a secondary string.  If it contains
	     ;; a time-stamp, convert it to internal format.
	     ;; Otherwise, use FILE modification time.
             (let ((ts (and (consp date) (assq 'timestamp date))))
	       (and ts
		    (let ((value (org-element-interpret-data ts)))
		      (and (org-string-nw-p value)
			   (org-time-string-to-time value))))))))))

(defun jrciii/org-publish-sitemap-entry (entry style project)
  "Custom format for site map ENTRY, as a string.
See `org-publish-sitemap-default-entry'."
  (cond ((not (directory-name-p entry))
         (let* ((meta-date (jrciii/org-publish-find-date entry project))
                (file (expand-file-name entry
                                        (org-publish-property :base-directory project)))
                (creation-date (if (not meta-date)
                                   (jrciii/git-creation-date file)
                                 ;; Default to the #+DATE value when specified.  This
                                 ;; can be useful, for instance, when Git gets the file
                                 ;; creation date wrong if the file was renamed.
                                 (format-time-string "%Y-%m-%d" meta-date)))
                (last-date (jrciii/git-last-update-date file)))
           (format "[[file:%s][%s]]^{ (%s)}"
                   entry
                   (org-publish-find-title entry project)
                   (if (string= creation-date last-date)
                       creation-date
                     (format "%s, updated %s" creation-date last-date)))))
	((eq style 'tree)
	 ;; Return only last subdir.
	 (capitalize (file-name-nondirectory (directory-file-name entry))))
	(t entry)))

(setq org-publish-project-alist
      (list
       (list "site-org"
             :base-directory "./source/"
             :recursive t
             :publishing-function '(org-html-publish-to-html)
             :publishing-directory "./" ; TODO: Set dir relative to root so that we can use "C-c C-e P".
             :sitemap-format-entry #'jrciii/org-publish-sitemap-entry
             :auto-sitemap t
             :sitemap-title "Posts"
             :sitemap-filename "posts.org"
             ;; :sitemap-file-entry-format "%d *%t*"
             :sitemap-style 'list
             :sitemap-function #'jrciii/org-publish-sitemap
             ;; :sitemap-ignore-case t
             :sitemap-sort-files 'anti-chronologically
             :html-head-include-default-style nil
             :html-head-include-scripts nil
	     :htmlized-source t
             :html-head "<link rel=\"stylesheet\" type=\"text/css\" href=\"../luxury.css\">"
	     )
       (list "site-static"
             :base-directory "source/"
             :exclude "\\.org\\'"
             :base-extension 'any
             :publishing-directory "./"
             :publishing-function 'org-publish-attachment
             :recursive t)
       (list "site" :components '("site-org"))))

(defun jrciii/publish ()
  (org-publish-all))

(provide 'publish)
;;; publish.el ends here
