/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2025 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "adc.h"
#include "dma.h"
#include "tim.h"
#include "usart.h"
#include "usb_device.h"
#include "gpio.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "usbd_cdc_if.h"
#include "stdio.h"
#include "math.h"
#include "string.h"
#include <stdbool.h>
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */
#define AMOSTRAS 2048
#define CANAIS 2
#define BUFFER_ADC (AMOSTRAS * CANAIS)
#define HALF_AMOSTRAS (AMOSTRAS / 2)
/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/

/* USER CODE BEGIN PV */
uint16_t analogico[BUFFER_ADC];

volatile bool halfReady = false;
volatile bool fullReady = false;

uint16_t sensorTensao[AMOSTRAS];
uint16_t sensorCorrente[AMOSTRAS];
/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
/* USER CODE BEGIN PFP */

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */
float converte_RMS(uint16_t *dados, uint32_t tamanho){
    const float adc_scale = 3.3f / 4095.0f;
    const float fator_tensao = 442.0f; // seu fator calibrado
    float offset = 0.0f;
    float soma = 0.0f;

    for(uint32_t i = 0; i < tamanho; i++){
        offset += dados[i];
    }
    offset /= tamanho;

    for(uint32_t i = 0; i < tamanho; i++){
        float v = (dados[i] - offset) * adc_scale;
        soma += v * v;
    }
    return sqrtf(soma / tamanho) * fator_tensao;
}


float calculaCorrenteRMS(uint16_t *dados, uint32_t tamanho){
	const float ganho = 0.00435f;      // fator ADC já convertido
	const float Irms_zero = 0.105f;    // ruído base calibrado
	 const float fatorCorrecao = 1.0f; // ajuste fino (se necessário)
	float offset = 0.0f;
	float soma = 0.0f;

	// Calcula offset médio
	for(uint32_t i = 0; i < tamanho; i++)
		offset += dados[i];

	offset /= tamanho;

	// Calcula soma dos quadrados
	for(uint32_t i = 0; i < tamanho; i++)
	{
		float corrente = (dados[i] - offset) * ganho;
		soma += corrente * corrente;
	}

	float Irms = sqrtf(soma / tamanho);

	// Remove ruído quadrático
	if(Irms > Irms_zero)
		Irms = sqrtf(Irms*Irms - Irms_zero*Irms_zero);
	else
		Irms = 0.0f;

	// Aplica correção final
	Irms *= fatorCorrecao;

	return Irms;

}


void enviaAmostrasCanal(uint16_t *buffer, uint8_t canal){
	static char usbBuffer[32];
	for(int i = 0; i < HALF_AMOSTRAS; i++){
		uint16_t valor = buffer[i * CANAIS + canal];
		int len = sprintf(usbBuffer,"%u\r\n",valor);
		while(CDC_Transmit_FS((uint8_t*)usbBuffer,len) == USBD_BUSY);
	}
}


void copiaCanal(uint16_t *buffer, uint16_t *destino, uint8_t canal){
    for(int i = 0; i < HALF_AMOSTRAS; i++){
        destino[i] = buffer[i * CANAIS + canal];
    }
}


void enviaRmsSerialMonitoramento(uint16_t *buffer){
    static uint16_t tempTensao[HALF_AMOSTRAS];
    static uint16_t tempCorrente[HALF_AMOSTRAS];

    static char usbBuffer[64];

    copiaCanal(buffer,tempTensao,0);
    copiaCanal(buffer,tempCorrente,1);

    float vrms = converte_RMS(tempTensao,HALF_AMOSTRAS);
    float irms = calculaCorrenteRMS(tempCorrente,HALF_AMOSTRAS);
    int len = sprintf(usbBuffer, "Vrms=%.2f Irms=%.2f\r\n", vrms, irms);
    while(CDC_Transmit_FS((uint8_t*)usbBuffer,len) == USBD_BUSY);
}


void enviaRmsEsp32(float vrms, float irms){
    static char uartBuffer[80];
    int len = sprintf(uartBuffer, "{\"vrms\":%.2f,\"irms\":%.2f}\n", vrms, irms);
    HAL_UART_Transmit(&huart1,(uint8_t*)uartBuffer,len,HAL_MAX_DELAY);
}

void enviaRmsEsp32FromBuffer(uint16_t *buffer){
    static uint16_t tempTensao[HALF_AMOSTRAS];
    static uint16_t tempCorrente[HALF_AMOSTRAS];

    copiaCanal(buffer,tempTensao,0);
    copiaCanal(buffer,tempCorrente,1);

    float vrms = converte_RMS(tempTensao,HALF_AMOSTRAS);
    float irms = calculaCorrenteRMS(tempCorrente,HALF_AMOSTRAS);

    enviaRmsEsp32(vrms,irms);
}



void HAL_ADC_ConvHalfCpltCallback(ADC_HandleTypeDef* hadc)
{
    if(hadc->Instance == ADC1)
        halfReady = true;
}

void HAL_ADC_ConvCpltCallback(ADC_HandleTypeDef* hadc) {
    if (hadc->Instance == ADC1) {
    	fullReady = true;
    }
}

/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_DMA_Init();
  MX_ADC1_Init();
  MX_USB_DEVICE_Init();
  MX_TIM2_Init();
  MX_USART1_UART_Init();
  /* USER CODE BEGIN 2 */
  HAL_TIM_Base_Start(&htim2);
  HAL_ADC_Start_DMA(&hadc1, (uint32_t*)analogico, BUFFER_ADC);
  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
  while (1){
	  if(halfReady){
		  halfReady = false;
		  enviaRmsEsp32FromBuffer(&analogico[0]);
	  }

	  if(fullReady){
		  enviaRmsEsp32FromBuffer(&analogico[HALF_AMOSTRAS * CANAIS]);
		  fullReady = false;
	  }

    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
  }
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Configure the main internal regulator output voltage
  */
  __HAL_RCC_PWR_CLK_ENABLE();
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE2);

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE;
  RCC_OscInitStruct.HSEState = RCC_HSE_ON;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSE;
  RCC_OscInitStruct.PLL.PLLM = 25;
  RCC_OscInitStruct.PLL.PLLN = 336;
  RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV4;
  RCC_OscInitStruct.PLL.PLLQ = 7;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV2;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_2) != HAL_OK)
  {
    Error_Handler();
  }
}

/* USER CODE BEGIN 4 */

/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}
#ifdef USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
