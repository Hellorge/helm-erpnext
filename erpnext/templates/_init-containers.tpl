{{- define "erpnext.initContainers.apps" -}}
{{- if .Values.persistentApps.enabled }}
- name: sync-apps
  image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  command: ["/bin/bash", "-c"]
  args:
    - |
      set -e
      echo "Syncing apps from persistent storage..."

      # If this is first run, copy default apps to persistent storage
      if [ ! -f {{ .Values.persistentApps.mountPath }}/.initialized ]; then
        echo "First run detected, initializing persistent apps..."
        cp -r /home/frappe/frappe-bench/apps/* {{ .Values.persistentApps.mountPath }}/
        touch {{ .Values.persistentApps.mountPath }}/.initialized
      else
        # Copy custom apps from persistent storage (excluding frappe and erpnext)
        for app in $(ls {{ .Values.persistentApps.mountPath }}); do
          if [ "$app" != "frappe" ] && [ "$app" != "erpnext" ] && [ "$app" != ".initialized" ] && [ -d "{{ .Values.persistentApps.mountPath }}/$app" ]; then
            if [ ! -d "/home/frappe/frappe-bench/apps/$app" ]; then
              echo "Restoring app: $app"
              cp -r "{{ .Values.persistentApps.mountPath }}/$app" "/home/frappe/frappe-bench/apps/"
            fi
          fi
        done

        # Install Python dependencies for custom apps
        cd /home/frappe/frappe-bench
        for app in $(ls apps); do
          if [ "$app" != "frappe" ] && [ "$app" != "erpnext" ] && [ -d "apps/$app" ]; then
            if [ -f "apps/$app/setup.py" ] || [ -f "apps/$app/pyproject.toml" ]; then
              echo "Installing dependencies for $app..."
              pip install -e "apps/$app" --no-cache-dir || true
            fi
          fi
        done
      fi
  volumeMounts:
  - name: apps
    mountPath: {{ .Values.persistentApps.mountPath }}
  - name: sites-dir
    mountPath: /home/frappe/frappe-bench/sites
  securityContext:
    {{- toYaml .Values.securityContext | nindent 4 }}
{{- end }}
{{- end }}
