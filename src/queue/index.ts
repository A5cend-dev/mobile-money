import { rabbitMQManager } from "./rabbitmq";
import { transactionQueue } from "./transactionQueue";
import { closeWorker } from "./worker";

export async function shutdownQueue(): Promise<void> {
  console.log("Shutting down queues...");
  await closeWorker().catch(() => undefined);
  await transactionQueue.close().catch(() => undefined);
  await rabbitMQManager.close().catch(() => undefined);
}

export {
  transactionQueue,
  addTransactionJob,
  getJobById,
  getJobProgress,
  getQueueStats,
  pauseQueue,
  resumeQueue,
  drainQueue,
} from "./transactionQueue";
export type {
  TransactionJobData,
  TransactionJobResult,
} from "./transactionQueue";
export { closeWorker };
export { createQueueDashboard } from "./dashboard";
export {
  getQueueHealth,
  pauseQueueEndpoint,
  resumeQueueEndpoint,
} from "./health";

