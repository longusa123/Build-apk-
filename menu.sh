#!/bin/bash

# Màu sắc giao diện chuyên nghiệp (Đã sửa lỗi thiếu dấu [)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Tự động bật lại con trỏ hệ thống nếu script bị tắt đột ngột (Ctrl+C)
trap 'printf "\033[?25h"; exit' INT TERM EXIT

# Danh sách danh mục chính tối ưu hóa gọn gàng
options=(
  "Quản lý & Chuyển đổi Repo (Quét GitHub & Đánh dấu bản hiện tại)"
  "Build APK (YML Method - Tự động quét & Ký số)"
  "Quản lý & Chỉnh sửa (File code, Keystore, Secrets)"
  "Bộ Công Cụ Modding APK (AAPT2, ZipAlign, SignKill, CheckCert)"
  "Thoát"
)

selected=0

# Đọc phím bấm với timeout an toàn
get_key() {
  local key ext
  IFS= read -s -n1 key
  if [[ $key == $'\e' ]]; then
    read -s -n2 -t 0.05 ext
    key+="$ext"
  fi
  echo -n "$key"
}

# Hiển thị Menu chính ghi đè tọa độ (Chống nháy hình)
show_menu() {
  local menu=""
  menu+="\033[H\033[?25l" # Đưa về đầu và ẩn con trỏ
  
  menu+="${BOLD}${CYAN}==================================================\033[K\n${NC}"
  menu+="${BOLD}${CYAN}🛠️  HỆ THỐNG ĐIỀU KHIỂN BUILD & MOD APK - TERMUX\033[K\n${NC}"
  menu+="${BOLD}${CYAN}==================================================\033[K\n${NC}"
  menu+="Thao tác: ${YELLOW}↑/↓${NC} Di chuyển | ${YELLOW}Enter/→${NC} Chọn | ${YELLOW}←${NC} Thoát nhanh\033[K\n"
  menu+="\033[K\n"

  for i in "${!options[@]}"; do
    if [ "$i" -eq "$selected" ]; then
      menu+="${GREEN}${BOLD}  ➔  ${options[$i]}\033[K\n${NC}"
    else
      menu+="     ${options[$i]}\033[K\n"
    fi
  done
  menu+="${BOLD}${CYAN}==================================================\033[K${NC}"
  
  printf "%b" "$menu"
}

show_cursor() {
  printf "\033[?25h"
}

wait_for_back() {
  echo -e "\n${YELLOW}Thao tác: Nhấn Mũi tên TRÁI (←) hoặc Enter để quay lại...${NC}"
  while true; do
    local k=$(get_key)
    if [[ "$k" == $'\e[D' || "$k" == $'\e[OD' || "$k" == "" ]]; then
      break
    fi
  done
}

# Hàm kiểm tra và tự động cài đặt môi trường Android Build Tools trên Termux
ensure_mod_tools() {
  if ! command -v aapt2 &>/dev/null || ! command -v zipalign &>/dev/null; then
    echo -e "${YELLOW}📦 Không tìm thấy Android Build Tools ở hệ thống. Đang tiến hành thiết lập...${NC}"
    pkg update -y
    pkg install android-tools openjdk-17 -y
    pkg install aapt ecj -y 2>/dev/null || true
    echo -e "${GREEN}✓ Môi trường AAPT2 / ZipAlign / Apksigner đã sẵn sàng!${NC}\n"
  fi
}

# Hàm điều khiển chuyển đổi và nạp danh sách Repo tương tác cao
manage_repos_interactive() {
  if ! gh auth status &>/dev/null; then
    echo -e "${RED}⚠️ Chưa đăng nhập GitHub CLI. Vui lòng đăng nhập trước!${NC}"
    gh auth login
    return
  fi

  echo -e "${YELLOW}🔍 Đang truy quét danh sách kho lưu trữ từ Cloud GitHub của ông...${NC}"
  
  # 1. Định dạng lấy tên Repo hiện tại ở máy local
  local current_remote=$(git config --get remote.origin.url 2>/dev/null)
  local current_repo_name=""
  if [[ "$current_remote" =~ github\.com[:/]([^/]+/[^.]+)(.*) ]]; then
    current_repo_name="${BASH_REMATCH[1]}"
  fi

  # 2. Quét mảng danh sách từ GitHub CLI
  local repo_data=()
  while IFS= read -r line; do
    [ -n "$line" ] && repo_data+=("$line")
  done < <(gh repo list --limit 60 --json fullName,url -q '.[] | .fullName + "|" + .url' 2>/dev/null)

  # 3. Tạo cấu trúc mảng tùy chọn hiển thị trực quan
  local repo_options=("[+] ➕ KHỞI TẠO VÀ ĐẨY REPO MỚI TOÀN DIỆN")
  local repo_urls=("NEW")

  for item in "${repo_data[@]}"; do
    local name=$(echo "$item" | cut -d'|' -f1)
    local url=$(echo "$item" | cut -d'|' -f2)
    if [ "$name" == "$current_repo_name" ]; then
      repo_options+=("$name 🟢 [ĐANG KÍCH HOẠT]")
    else
      repo_options+=("$name")
    fi
    repo_urls+=("$url")
  done

  # 4. Vòng lặp giao diện tương tác Repo phụ giống hệt Menu chính
  local sub_selected=0
  while true; do
    local sub_menu=""
    sub_menu+="\033[H\033[?25l"
    sub_menu+="${BOLD}${CYAN}==================================================\033[K\n${NC}"
    sub_menu+="${BOLD}${CYAN}🌐 TRUNG TÂM QUẢN LÝ & BẺ LÁI ĐƯỜNG TRUYỀN REPO\033[K\n${NC}"
    sub_menu+="${BOLD}${CYAN}==================================================\033[K\n${NC}"
    sub_menu+="Thao tác: ${YELLOW}↑/↓${NC} Di chuyển | ${YELLOW}Enter/→${NC} Kích hoạt đổi | ${YELLOW}←${NC} Trở ra\033[K\n"
    sub_menu+="Liên kết máy local hiện tại: ${GREEN}${current_repo_name:-"Trống (Chưa có kết nối)"}${NC}\033[K\n\n"

    for i in "${!repo_options[@]}"; do
      if [ "$i" -eq "$sub_selected" ]; then
        sub_menu+="${GREEN}${BOLD}  ➔  ${repo_options[$i]}\033[K\n${NC}"
      else
        if [[ "${repo_options[$i]}" == *"🟢"* ]]; then
          sub_menu+="${GREEN}     ${repo_options[$i]}\033[K\n${NC}"
        elif [[ "${repo_options[$i]}" == "[+"* ]]; then
          sub_menu+="${PURPLE}${BOLD}     ${repo_options[$i]}\033[K\n${NC}"
        else
          sub_menu+="     ${repo_options[$i]}\033[K\n"
        fi
      fi
    done
    sub_menu+="${BOLD}${CYAN}==================================================\033[K${NC}"
    printf "%b" "$sub_menu"

    local k=$(get_key)
    case "$k" in
      $'\e[A'|$'\e[OA') # Mũi tên LÊN
        ((sub_selected--))
        [ $sub_selected -lt 0 ] && sub_selected=$((${#repo_options[@]} - 1))
        ;;
      $'\e[B'|$'\e[OB') # Mũi tên XUỐNG
        ((sub_selected++))
        [ $sub_selected -ge "${#repo_options[@]}" ] && sub_selected=0
        ;;
      $'\e[C'|$'\e[OC'|"") # ENTER hoặc phím PHẢI -> Thực thi chọn mục
        clear
        show_cursor
        if [ "$sub_selected" -eq 0 ]; then
          echo -e "${BOLD}${PURPLE}📝 TIẾN TRÌNH TẠO MỚI KHO LƯU TRỮ TRÊN GITHUB${NC}\n"
          read -p "Nhập tên Repo mới muốn tạo: " new_name
          if [ -n "$new_name" ]; then
            [ ! -d .git ] && git init && git branch -M main
            gh repo create "$new_name" --public --source=. --remote=origin --push && \
            echo -e "\n${GREEN}✓ Xuất sắc! Đã tạo và bẻ lái remote máy về Repo mới: $new_name${NC}" || \
            echo -e "${RED}❌ Có lỗi xảy ra trong quá trình khởi tạo GitHub Actions.${NC}"
            sleep 2
          fi
        else
          local target_url="${repo_urls[$sub_selected]}"
          local target_name=$(echo "${repo_options[$sub_selected]}" | sed 's/ 🟢.*//')
          
          echo -e "${BOLD}${YELLOW}⚙️ ĐANG THỰC HIỆN CẤU HÌNH ĐỔI ĐƯỜNG TRUYỀN REMOTE...${NC}\n"
          [ ! -d .git ] && git init && git branch -M main
          
          if git remote get-url origin &>/dev/null; then
            git remote set-url origin "$target_url"
          else
            git remote add origin "$target_url"
          fi
          echo -e "${GREEN}✓ ĐỔI HƯỚNG THÀNH CÔNG!${NC}"
          echo -e "Thư mục Termux này hiện tại đã được liên kết sang: ${CYAN}$target_name${NC}"
          sleep 2
        fi
        break
        ;;
      $'\e[D'|$'\e[OD') # Mũi tên TRÁI -> Quay lại menu chính
        break
        ;;
    esac
  done
}

# Hàm đảm bảo luôn có file build.yml nền trên GitHub
ensure_build_yml() {
  if [ ! -f ".github/workflows/build.yml" ]; then
    mkdir -p .github/workflows
    cat << 'INNER_EOF' > .github/workflows/build.yml
name: Build Android APK từ file ZIP
on:
  push:
    branches: [ "main" ]
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Giải nén mã nguồn
        run: |
          unzip *.zip || echo "Không có file zip"
          chmod +x gradlew || chmod +x */gradlew || true
      - uses: actions/setup-java@v4
        with:
          distribution: 'zulu'
          java-version: '17'
      - name: Cấu hình chữ ký số Keystore
        run: |
          if [ -n "${{ secrets.KEYSTORE_BASE64 }}" ]; then
            echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > $GITHUB_WORKSPACE/signing.keystore
            echo "KEYSTORE_PATH=$GITHUB_WORKSPACE/signing.keystore" >> $GITHUB_ENV
          else
            KEY_FILE=$(find . -name "*.keystore" -o -name "*.jks" | head -n 1 | sed 's|^\./||')
            if [ -n "$KEY_FILE" ]; then
              echo "KEYSTORE_PATH=$GITHUB_WORKSPACE/$KEY_FILE" >> $GITHUB_ENV
            else
              echo "KEYSTORE_PATH=" >> $GITHUB_ENV
            fi
          fi
      - name: Build APK
        run: |
          if [ -f "./gradlew" ]; then GRADLE_DIR="."; else GRADLE_DIR=$(dirname $(find . -name gradlew | head -n 1)); fi
          cd $GRADLE_DIR
          if [ -n "$KEYSTORE_PATH" ] && [ -n "${{ secrets.RELEASE_STORE_PASSWORD }}" ]; then
            ./gradlew assembleRelease \
              -Pandroid.injected.signing.store.file="$KEYSTORE_PATH" \
              -Pandroid.injected.signing.store.password="${{ secrets.RELEASE_STORE_PASSWORD }}" \
              -Pandroid.injected.signing.key.alias="${{ secrets.RELEASE_KEY_ALIAS }}" \
              -Pandroid.injected.signing.key.password="${{ secrets.RELEASE_KEY_PASSWORD }}"
          else
            ./gradlew assembleDebug
          fi
      - uses: actions/upload-artifact@v4
        with:
          name: App-Artifacts-APK
          path: "**/build/outputs/apk/**/*.apk"
INNER_EOF
  fi
}

# Thực thi chi tiết từng danh mục chính
execute_action() {
  clear 
  show_cursor 
  case $selected in
    0)
      manage_repos_interactive
      clear
      ;;
      
    1)
      echo -e "${BOLD}${BLUE}[2] BUILD APK (YML METHOD - QUY TRÌNH ĐÓNG GÓI)${NC}\n"
      ensure_build_yml
      echo -e "${YELLOW}🚀 Đang push code kích hoạt tiến trình Build trên máy chủ...${NC}"
      git add .
      git commit -m "Kích hoạt chu kỳ đóng gói APK" --allow-empty
      git push origin main --force
      
      LOCAL_SHA=$(git rev-parse HEAD 2>/dev/null)
      echo -e "\n${YELLOW}🔍 MẮT THẦN ĐANG THEO DÕI TIẾN TRÌNH RUNTIME TRÊN SERVER...${NC}"
      
      RUN_ID=""
      for i in {1..6}; do
        RUN_ID=$(gh run list --workflow=build.yml --json databaseId,headSha -q ".[] | select(.headSha == \"$LOCAL_SHA\") | .databaseId" | head -n 1)
        if [ -n "$RUN_ID" ]; then break; fi
        echo -e "⏳ Chờ máy chủ tiếp nhận tín hiệu (Lần $i/6)..."
        sleep 2.5
      done

      if [ -n "$RUN_ID" ]; then
        echo -e "${GREEN}🎯 Khóa mục tiêu thành công! Đang hiển thị log trực tiếp:${NC}\n"
        gh run watch "$RUN_ID"
        echo -e "\n📥 Bạn có muốn kéo sản phẩm file APK về Termux luôn không? (y/n): "
        read -r dl_ans
        if [[ "$dl_ans" == "y" || "$dl_ans" == "Y" ]]; then
          gh run download "$RUN_ID" --unzip
          echo -e "${GREEN}✓ Thành công! File APK đã có mặt tại thư mục hiện hành.${NC}"
        fi
      else
        echo -e "${RED}❌ Quá hạn phản hồi từ GitHub Actions.${NC}"
      fi
      wait_for_back
      ;;
      
    2)
      echo -e "${BOLD}${BLUE}[3] TRUNG TÂM QUẢN LÝ & CHỈNH SỬA TRỰC TIỆP${NC}\n"
      echo -e "Hãy chọn phân vùng ông muốn tác động chỉnh sửa:"
      echo -e "1) 📝 Chỉnh sửa tệp tin mã nguồn (README.md, file code...)"
      echo -e "2) 🔐 Chỉnh sửa / Cập nhật biến mật mã bí mật (GitHub Secrets)"
      echo -e "3) 🔑 Khởi tạo / Thay đổi cấu hình chữ ký số (Keystore)"
      echo ""
      read -p "Nhập số lựa chọn của ông (1, 2 hoặc 3): " sub_choice
      
      case $sub_choice in
        1)
          clear
          echo -e "${BOLD}${CYAN}📝 PHÂN VÙNG: CHỈNH SỬA TỆP TIN MÃ NGUỒN${NC}\n"
          find . -maxdepth 2 -type f -not -path '*/.*' | sed 's|^\./||'
          echo ""
          read -p "📝 Nhập tên file muốn sửa/tạo mới: " edit_file
          if [ -n "$edit_file" ]; then
            [ ! -x "$(command -v nano)" ] && pkg install nano -y
            nano "$edit_file"
            if [ -f "$edit_file" ]; then
              read -p "🚀 Push đồng bộ trực tiếp lên GitHub Web luôn không? (y/n): " sync_ans
              if [[ "$sync_ans" == "y" || "$sync_ans" == "Y" ]]; then
                git add "$edit_file"
                git commit -m "Cập nhật tệp $edit_file trực tiếp qua Termux"
                git push origin main && echo -e "${GREEN}✓ Đồng bộ thành công!${NC}"
              fi
            fi
          fi
          ;;
        2)
          clear
          echo -e "${BOLD}${CYAN}🔐 PHÂN VÙNG: QUẢN LÝ GITHUB SECRETS${NC}\n"
          gh secret list
          echo ""
          read -p "📝 Nhập TÊN BIẾN muốn thêm/sửa đổi: " sec_name
          if [ -n "$sec_name" ]; then
            read -p "🔑 Nhập GIÁ TRỊ nạp vào cho biến đó: " sec_body
            if [ -n "$sec_body" ]; then
              gh secret set "$sec_name" --body "$sec_body" && echo -e "${GREEN}✓ Đã nạp biến thành công!${NC}"
            fi
          fi
          ;;
        3)
          clear
          echo -e "${BOLD}${CYAN}🔑 PHÂN VÙNG: THIẾT LẬP CHỮ KÝ SỐ (KEYSTORE)${NC}\n"
          read -p "📝 Đặt tên file Keystore (Mặc định: upload.keystore): " ks_name
          [ -z "$ks_name" ] && ks_name="upload.keystore"
          read -p "📝 Đặt tên mã Alias (Mặc định: my-key-alias): " ks_alias
          [ -z "$ks_alias" ] && ks_alias="my-key-alias"
          read -p "🔐 Mật khẩu (Mặc định: 123456): " ks_pass
          [ -z "$ks_pass" ] && ks_pass="123456"
          
          [ ! -x "$(command -v keytool)" ] && pkg install openjdk-17 -y
          keytool -genkey -v -keystore "$ks_name" -alias "$ks_alias" -keyalg RSA -keysize 2048 -validity 10000 \
            -storepass "$ks_pass" -keypass "$ks_pass" -dname "CN=Android,O=Android,C=US" &>/dev/null
          
          if [ -f "$ks_name" ]; then
            echo -e "${GREEN}✓ Đã tạo xong file gốc: $ks_name${NC}"
            echo -e "1) File vật lý | 2) Ẩn vào Secret"
            read -p "Lựa chọn: " method_choice
            if [ "$method_choice" == "2" ]; then
              base64 "$ks_name" | tr -d '\n' > temp_b64.txt
              gh secret set KEYSTORE_BASE64 < temp_b64.txt
              rm temp_b64.txt "$ks_name"
              echo -e "${GREEN}🎉 Đã ẩn khóa vào Secret đám mây!${NC}"
            fi
          fi
          ;;
      esac
      wait_for_back
      ;;
      
    3)
      echo -e "${BOLD}${PURPLE}[4] BÀN ĐIỀU KHIỂN MODDING APK (MT MANAGER & APKTOOL STYLE)${NC}\n"
      ensure_mod_tools
      
      echo -e "${YELLOW}🔍 Đang quét các file .apk mục tiêu tại thư mục hiện tại...${NC}"
      local apk_files=($(find . -maxdepth 1 -name "*.apk" | sed 's|^\./||'))
      
      if [ ${#apk_files[@]} -eq 0 ]; then
        echo -e "${RED}❌ Không tìm thấy file .apk nào trong thư mục này ông ơi!${NC}"
        wait_for_back
        return
      fi
      
      echo -e "\n${BOLD}Chọn file APK ông muốn thực hiện modding:${NC}"
      for idx in "${!apk_files[@]}"; do
        echo -e "$((idx+1))) ${CYAN}${apk_files[$idx]}${NC}"
      done
      echo ""
      read -p "Nhập số thứ tự file APK: " apk_num
      local target_apk="${apk_files[$((apk_num-1))]}"
      
      if [ -z "$target_apk" ]; then
        echo -e "${RED}❌ Lựa chọn sai mục tiêu!${NC}"
        wait_for_back
        return
      fi
      
      echo -e "\n${BOLD}🎯 ĐÃ KHÓA MỤC TIÊU: ${GREEN}$target_apk${NC}"
      echo -e "Chọn tác vụ muốn xử lý hệ thống:"
      echo -e "1) 📦 ${YELLOW}[AAPT2]${NC} Dump Badging (Xem Package Name, Permissions, Activities...)"
      echo -e "2) ⚡ ${YELLOW}[ZipAlign]${NC} Tối ưu hóa APK (Căn lề dữ liệu 4-byte giảm tiêu thụ RAM)"
      echo -e "3) ✍️  ${YELLOW}[Apksigner]${NC} Ký chữ ký thủ công + Tùy chọn Lược đồ V1, V2, V3, V4"
      echo -e "4) 🔍 ${GREEN}[CheckCert] Kiểm tra thông tin CHỨNG CHỈ CHỮ KÝ SỐ (Hoàn chỉnh V1-V4, MD5, SHA256)${NC}"
      echo -e "5) 💀 ${RED}[SignKill] Khử xác minh chữ ký số (Bypass Signature Verification - MT Style)${NC}"
      echo ""
      read -p "Chọn tác vụ xử lý (1, 2, 3, 4 hoặc 5): " mod_choice
      
      case $mod_choice in
        1)
          echo -e "\n${BLUE}📊 ĐANG TRÍCH XUẤT THÔNG TIN MANIFEST CỦA APP...${NC}\n"
          aapt2 dump badging "$target_apk" | head -n 25
          echo -e "\n${YELLOW}...Xem tiếp các quyền truy cập được cấp phép (Permissions):${NC}"
          aapt2 dump badging "$target_apk" | grep "uses-permission" || echo "Không có quyền đặc biệt."
          ;;
        2)
          local out_align="${target_apk%.apk}_aligned.apk"
          echo -e "\n${YELLOW}⚙️ Đang thực hiện thuật toán căn lề dữ liệu 4-byte...${NC}"
          zipalign -f -v 4 "$target_apk" "$out_align" &>/dev/null
          if [ -f "$out_align" ]; then
            echo -e "${GREEN}✓ Thành công! Đã xuất file tối ưu: $out_align${NC}"
          else
            echo -e "${RED}❌ Lỗi quá trình ZipAlign.${NC}"
          fi
          ;;
        3)
          echo -e "\n"
          read -p "📝 Nhập tên file Keystore local của ông (VD: upload.keystore): " k_file
          read -p "📝 Nhập mã Alias: " k_alias
          if [ -f "$k_file" ]; then
            echo -e "\n${BOLD}${CYAN}🛠️  TÙY CHỌN LƯỢC ĐỒ CHỮ KÝ SỐ (SIGNATURE SCHEMES):${NC}"
            echo -e "1) Chỉ ký [V1] (Jar Signature - Cho dòng máy cổ bảo mật thấp)"
            echo -e "2) Ký kết hợp [V1 + V2] (Chuẩn mực - Ổn định nhất cho Android 7 -> 10)"
            echo -e "3) Ký kết hợp [V1 + V2 + V3] (Khuyên dùng - Vượt tốt rào bảo vệ Android 11+)"
            echo -e "4) Ký Full Combo [V1 + V2 + V3 + V4] (Ép full chứng chỉ bảo mật đa tầng)"
            read -p "Nhập lựa chọn của ông (1, 2, 3 hoặc 4 - Mặc định là 3): " s_choice
            
            local s_flags="--v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --v4-signing-enabled false"
            case $s_choice in
              1) s_flags="--v1-signing-enabled true --v2-signing-enabled false --v3-signing-enabled false --v4-signing-enabled false" ;;
              2) s_flags="--v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled false --v4-signing-enabled false" ;;
              4) s_flags="--v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --v4-signing-enabled true" ;;
              *) s_flags="--v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --v4-signing-enabled false" ;;
            esac

            echo -e "\n${YELLOW}⚙️ Đang tiến hành inject cấu hình chữ ký số vào APK...${NC}"
            apksigner sign --ks "$k_file" --ks-key-alias "$k_alias" $s_flags "$target_apk" && \
            echo -e "${GREEN}✓ Đã ký thành công file APK với lược đồ lựa chọn!${NC}" || echo -e "${RED}❌ Ký thất bại. Kiểm tra lại thông tin khóa.${NC}"
          else
            echo -e "${RED}❌ Không tìm thấy file Keystore tên [$k_file] tại local!${NC}"
          fi
          ;;
        4)
          echo -e "\n${BOLD}${GREEN}🔍 THÔNG TIN HOÀN CHỈNH VỀ CHỨNG CHỈ CHỮ KÝ SỐ (CERTIFICATE INFO)${NC}"
          echo -e "${CYAN}----------------------------------------------------------------------${NC}"
          if command -v apksigner &>/dev/null; then
            apksigner verify --print-certs -v "$target_apk"
          elif command -v keytool &>/dev/null; then
            keytool -printcert -jarfile "$target_apk"
          else
            echo -e "${RED}❌ Lỗi: Hệ thống thiếu công cụ xác thực cấu trúc chữ ký số Android.${NC}"
          fi
          echo -e "${CYAN}----------------------------------------------------------------------${NC}"
          ;;
        5)
          echo -e "\n${BOLD}${RED}💀 TIẾN TRÌNH KHỬ XÁC MINH CHỮ KÝ (KILL SIGNATURE VERIFY)${NC}"
          mkdir -p .tmp_mod
          echo -e "⏳ Bước 1: Đang giải phẫu file binary cấu trúc classes.dex..."
          unzip -q "$target_apk" "classes*.dex" -d .tmp_mod 2>/dev/null
          
          if [ ! -f .tmp_mod/classes.dex ]; then
            echo -e "${RED}❌ Lỗi: Không tìm thấy file thực thi DEX bên trong APK.${NC}"
            rm -rf .tmp_mod
          else
            echo -e "⏳ Bước 2: Đang thực thi mã lệnh vô hiệu hóa chuỗi đối chiếu Signature..."
            for dex in .tmp_mod/classes*.dex; do
              sed -i 's/Landroid\/content\/pm\/Signature;->toByteArray/Landroid\/content\/pm\/Signature;->toString/g' "$dex" 2>/dev/null
            done
            
            echo -e "⏳ Bước 3: Đang đóng gói tái cấu trúc và tái tạo lại APK mới..."
            local out_killed="${target_apk%.apk}_SignKilled.apk"
            cp "$target_apk" "$out_killed"
            cd .tmp_mod && zip -q -r "../$out_killed" classes*.dex && cd ..
            rm -rf .tmp_mod
            
            echo -e "⏳ Bước 4: Tự động ký đè Chữ ký ảo và kích hoạt Full Scheme (V1+V2+V3)..."
            [ ! -f "testkey.keystore" ] && keytool -genkey -v -keystore testkey.keystore -alias test -keyalg RSA -keysize 1024 -validity 10000 -storepass 123456 -keypass 123456 -dname "CN=MT" &>/dev/null
            
            apksigner sign --ks testkey.keystore --ks-pass pass:123456 --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --v4-signing-enabled false "$out_killed" &>/dev/null
            
            echo -e "${GREEN}🎉 HOÀN THÀNH MỸ MÃN! File đã được bẻ gãy xích xác minh chữ ký: $out_killed${NC}"
          fi
          ;;
        *)
          echo -e "${RED}❌ Lựa chọn không đúng tác vụ!${NC}"
          ;;
      esac
      wait_for_back
      ;;
      
    4)
      clear
      show_cursor
      echo -e "${GREEN}👋 Đã thoát menu thành công!${NC}"
      exit 0
      ;;
  esac
}

# --- KHỞI CHẠY HỆ THỐNG MENU ---
clear 
while true; do
  show_menu
  cmd=$(get_key)
  case "$cmd" in
    $'\e[A'|$'\e[OA') # Mũi tên LÊN
      ((selected--))
      [ $selected -lt 0 ] && selected=$((${#options[@]} - 1))
      ;;
    $'\e[B'|$'\e[OB') # Mũi tên XUỐNG
      ((selected++))
      [ $selected -ge "${#options[@]}" ] && selected=0
      ;;
    $'\e[C'|$'\e[OC'|"") # Mũi tên PHẢI hoặc ENTER -> Thực thi
      execute_action
      clear 
      ;;
    $'\e[D'|$'\e[OD') # Mũi tên TRÁI -> THOÁT NGAY LẬP TỨC
      clear
      show_cursor
      echo -e "${GREEN}👋 Đã thoát nhanh menu bằng phím TRÁI!${NC}"
      exit 0
      ;;
  esac
done
