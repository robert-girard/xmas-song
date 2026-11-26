#include <stdbool.h>
#include <string.h>

#include "button_gpio.h"
#include "iot_button.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "host/ble_hs.h"
#include "host/ble_hs_id.h"
#include "host/util/util.h"
#include "host/ble_gap.h"
#include "host/ble_gatt.h"
#include "host/ble_uuid.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"
#include "freertos/FreeRTOS.h"

static const char *TAG = "xmas_button";

#define COMMAND_PLAY_PAUSE 0x01
#define COMMAND_NEXT       0x02
#define COMMAND_PREVIOUS   0x03
#define COMMAND_STOP       0x04
#define COMMAND_SHUFFLE    0x05

static const ble_uuid128_t service_uuid = BLE_UUID128_INIT(
    0x7c, 0xea, 0xe3, 0x40, 0xec, 0xa4, 0xd6, 0xba,
    0xf4, 0x42, 0x2b, 0xda, 0x80, 0x3b, 0xf9, 0x55);
static const ble_uuid128_t command_uuid = BLE_UUID128_INIT(
    0x5e, 0x33, 0x53, 0xc0, 0x66, 0xd0, 0xf4, 0x98,
    0x76, 0x41, 0xb7, 0x99, 0x57, 0xa5, 0x06, 0x22);

static uint16_t command_value_handle;
static uint16_t subscribed_conn = BLE_HS_CONN_HANDLE_NONE;
static bool notification_enabled;
static uint32_t subscription_generation;
static uint16_t click_conn = BLE_HS_CONN_HANDLE_NONE;
static uint32_t click_generation;
static bool click_pending;
static portMUX_TYPE subscription_mux = portMUX_INITIALIZER_UNLOCKED;
static uint8_t own_addr_type;
static struct ble_npl_event click_event;
#if CONFIG_XMAS_BUTTON_GPIO_VERIFIED
static button_handle_t button_handle;
#endif

static int command_access(uint16_t conn_handle, uint16_t attr_handle,
                          struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    (void)conn_handle;
    (void)attr_handle;
    (void)arg;
    if (ctxt->op == BLE_GATT_ACCESS_OP_READ_CHR) {
        return BLE_ATT_ERR_READ_NOT_PERMITTED;
    }
    if (ctxt->op == BLE_GATT_ACCESS_OP_WRITE_CHR) {
        return BLE_ATT_ERR_WRITE_NOT_PERMITTED;
    }
    return BLE_ATT_ERR_UNLIKELY;
}

static const struct ble_gatt_svc_def services[] = {
    {
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &service_uuid.u,
        .characteristics = (struct ble_gatt_chr_def[]) {
            {
                .uuid = &command_uuid.u,
                .access_cb = command_access,
                .val_handle = &command_value_handle,
                .flags = BLE_GATT_CHR_F_NOTIFY,
            },
            {0}
        },
    },
    {0}
};

static void gatt_register(struct ble_gatt_register_ctxt *ctxt, void *arg)
{
    (void)arg;
    if (ctxt->op == BLE_GATT_REGISTER_OP_CHR) {
        ESP_LOGI(TAG, "GATT characteristic registered");
    }
}

static void send_play_pause(struct ble_npl_event *event)
{
    (void)event;
    uint16_t conn_handle;
    uint32_t click_generation_snapshot;
    uint32_t subscription_generation_snapshot;
    bool should_send;
    portENTER_CRITICAL(&subscription_mux);
    should_send = click_pending && notification_enabled &&
                  click_conn == subscribed_conn &&
                  click_generation == subscription_generation &&
                  subscribed_conn != BLE_HS_CONN_HANDLE_NONE;
    conn_handle = subscribed_conn;
    click_generation_snapshot = click_generation;
    subscription_generation_snapshot = subscription_generation;
    click_pending = false;
    portEXIT_CRITICAL(&subscription_mux);
    if (!should_send) {
        return;
    }

    /* Recheck immediately before sending in case the subscription changed. */
    portENTER_CRITICAL(&subscription_mux);
    should_send = notification_enabled &&
                  subscribed_conn == conn_handle &&
                  subscription_generation == subscription_generation_snapshot &&
                  click_generation_snapshot == subscription_generation_snapshot;
    portEXIT_CRITICAL(&subscription_mux);
    if (!should_send) {
        return;
    }

    const uint8_t command = COMMAND_PLAY_PAUSE;
    struct os_mbuf *om = ble_hs_mbuf_from_flat(&command, sizeof(command));
    if (om == NULL) {
        ESP_LOGE(TAG, "Unable to allocate command notification");
        return;
    }
    const int rc = ble_gatts_notify_custom(conn_handle, command_value_handle, om);
    if (rc != 0) {
        ESP_LOGW(TAG, "Notification failed: %d", rc);
    }
}

#if CONFIG_XMAS_BUTTON_GPIO_VERIFIED
static void button_event(void *button_arg, void *user_data)
{
    (void)button_arg;
    (void)user_data;
    bool active_subscription;
    portENTER_CRITICAL(&subscription_mux);
    active_subscription = notification_enabled &&
                          subscribed_conn != BLE_HS_CONN_HANDLE_NONE;
    if (active_subscription) {
        click_conn = subscribed_conn;
        click_generation = subscription_generation;
        click_pending = true;
    }
    portEXIT_CRITICAL(&subscription_mux);
    if (active_subscription) {
        ble_npl_eventq_put(nimble_port_get_dflt_eventq(), &click_event);
    }
}

#endif

static void clear_subscription(void)
{
    portENTER_CRITICAL(&subscription_mux);
    subscribed_conn = BLE_HS_CONN_HANDLE_NONE;
    notification_enabled = false;
    click_pending = false;
    ++subscription_generation;
    portEXIT_CRITICAL(&subscription_mux);
}

static int gap_event(struct ble_gap_event *event, void *arg)
{
    (void)arg;
    switch (event->type) {
    case BLE_GAP_EVENT_CONNECT:
        if (event->connect.status == 0) {
            clear_subscription();
            ESP_LOGI(TAG, "Connected");
        } else {
            clear_subscription();
            ble_gap_adv_start(own_addr_type, NULL, BLE_HS_FOREVER,
                              &(struct ble_gap_adv_params) {
                                  .conn_mode = BLE_GAP_CONN_MODE_UND,
                                  .disc_mode = BLE_GAP_DISC_MODE_GEN,
                              }, gap_event, NULL);
        }
        return 0;
    case BLE_GAP_EVENT_DISCONNECT:
        clear_subscription();
        ESP_LOGI(TAG, "Disconnected");
        ble_gap_adv_start(own_addr_type, NULL, BLE_HS_FOREVER,
                          &(struct ble_gap_adv_params) {
                              .conn_mode = BLE_GAP_CONN_MODE_UND,
                              .disc_mode = BLE_GAP_DISC_MODE_GEN,
                          }, gap_event, NULL);
        return 0;
    case BLE_GAP_EVENT_SUBSCRIBE:
        if (event->subscribe.attr_handle == command_value_handle) {
            portENTER_CRITICAL(&subscription_mux);
            if (event->subscribe.cur_notify) {
                subscribed_conn = event->subscribe.conn_handle;
                notification_enabled = true;
                ++subscription_generation;
                click_pending = false;
            } else if (subscribed_conn == event->subscribe.conn_handle) {
                notification_enabled = false;
                subscribed_conn = BLE_HS_CONN_HANDLE_NONE;
                ++subscription_generation;
                click_pending = false;
            }
            portEXIT_CRITICAL(&subscription_mux);
        }
        return 0;
    default:
        return 0;
    }
}

static void advertise(void)
{
    struct ble_hs_adv_fields adv = {0};
    struct ble_hs_adv_fields rsp = {0};
    adv.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    adv.uuids128 = (ble_uuid128_t *)&service_uuid;
    adv.num_uuids128 = 1;
    adv.uuids128_is_complete = 1;
    rsp.name = (uint8_t *)"Xmas Button";
    rsp.name_len = strlen("Xmas Button");
    rsp.name_is_complete = 1;
    int rc = ble_gap_adv_set_fields(&adv);
    if (rc == 0) rc = ble_gap_adv_rsp_set_fields(&rsp);
    if (rc != 0) {
        ESP_LOGE(TAG, "Advertising fields failed: %d", rc);
        return;
    }
    const struct ble_gap_adv_params params = {
        .conn_mode = BLE_GAP_CONN_MODE_UND,
        .disc_mode = BLE_GAP_DISC_MODE_GEN,
    };
    rc = ble_gap_adv_start(own_addr_type, NULL, BLE_HS_FOREVER,
                           &params, gap_event, NULL);
    if (rc != 0) ESP_LOGE(TAG, "Advertising start failed: %d", rc);
}

static void on_sync(void)
{
    int rc = ble_hs_util_ensure_addr(0);
    if (rc == 0) rc = ble_hs_id_infer_auto(0, &own_addr_type);
    if (rc != 0) {
        ESP_LOGE(TAG, "BLE address setup failed: %d", rc);
        return;
    }
    advertise();
}

static void nimble_host_task(void *arg)
{
    (void)arg;
    nimble_port_run();
    nimble_port_freertos_deinit();
}

static void init_button(void)
{
#if CONFIG_XMAS_BUTTON_GPIO_VERIFIED
    const button_config_t button_config = {0};
    const button_gpio_config_t gpio_config = {
        .gpio_num = CONFIG_XMAS_BUTTON_GPIO,
        .active_level = 0,
        .enable_power_save = false,
    };
    ESP_ERROR_CHECK(iot_button_new_gpio_device(&button_config, &gpio_config,
                                               &button_handle));
    ESP_ERROR_CHECK(iot_button_register_cb(button_handle, BUTTON_SINGLE_CLICK,
                                            NULL, button_event, NULL));
#else
    ESP_LOGW(TAG, "Button GPIO disabled pending verified board wiring");
#endif
}

void app_main(void)
{
    esp_err_t err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        err = nvs_flash_init();
    }
    ESP_ERROR_CHECK(err);
    ESP_ERROR_CHECK(nimble_port_init());
    ble_svc_gap_init();
    ble_svc_gatt_init();
    ble_svc_gap_device_name_set("Xmas Button");
    ble_hs_cfg.sync_cb = on_sync;
    ble_hs_cfg.gatts_register_cb = gatt_register;
    ble_npl_event_init(&click_event, send_play_pause, NULL);
    ESP_ERROR_CHECK(ble_gatts_count_cfg(services));
    ESP_ERROR_CHECK(ble_gatts_add_svcs(services));
    init_button();
    nimble_port_freertos_init(nimble_host_task);
}
